import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../../convex/_generated/api"
import { decryptToken, encryptToken } from "@/lib/health/token-crypto"
import { PullError, canPull, pull, refreshAccessToken } from "@/lib/health/provider-pull"
import { oauthProvider, credentialsFor } from "@/lib/health/oauth-providers"

export const dynamic = "force-dynamic"
export const maxDuration = 60

/**
 * Pull one provider's measurements into the ledger.
 *
 * Everything runs as the caller. The phone sends its Clerk token, that token
 * reads the caller's own encrypted envelope out of Convex, this layer decrypts
 * it — the key never leaves here — calls the provider, converts to the
 * canonical vocabulary, and writes back through the same identity. At no point
 * does the server hold a credential that can reach another account's data.
 *
 * Refresh happens first and unconditionally when a refresh token exists.
 * Access tokens from all three of these expire in hours, and the failure mode
 * of not refreshing is a connection that works on the day it's made and
 * silently stops afterwards — which reads as a broken integration rather than
 * an expired one.
 */
export async function POST(
  request: Request,
  { params }: { params: Promise<{ provider: string }> },
) {
  const { provider } = await params

  const { userId, getToken } = await auth()
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
  const token = bearer || (await getToken({ template: "convex" }))
  if (!token) {
    return NextResponse.json({ error: "No Convex credential on this request" }, { status: 401 })
  }

  const spec = oauthProvider(provider)
  if (!spec || !canPull(provider)) {
    return NextResponse.json({ error: `Can't sync "${provider}"` }, { status: 400 })
  }
  if (!credentialsFor(spec)) {
    // Honest and specific: this is a server configuration gap, not the user's
    // connection having failed.
    return NextResponse.json(
      {
        error: `${spec.label} isn't set up on this server yet — it needs ${spec.clientIdEnv} and ${spec.clientSecretEnv}.`,
      },
      { status: 503 },
    )
  }

  const body = (await request.json().catch(() => ({}))) as { days?: number }
  const days = Number.isFinite(body?.days) ? Math.min(Number(body.days), 90) : 7

  const convex = getConvexClient(token)

  try {
    const row = await convex.query(api.health.tokens.mine, { provider })
    if (!row?.access_token) {
      return NextResponse.json(
        { error: `${spec.label} isn't connected to this account.` },
        { status: 409 },
      )
    }

    let access = decryptToken(row.access_token)
    const refresh = row.refresh_token ? decryptToken(row.refresh_token) : undefined

    const renewed = await refreshAccessToken(provider, refresh)
    if (renewed?.access_token) {
      access = renewed.access_token
      await convex.mutation(api.health.tokens.saveMine, {
        provider,
        access_token: encryptToken(renewed.access_token),
        refresh_token: renewed.refresh_token
          ? encryptToken(renewed.refresh_token)
          : undefined,
        expires_at: renewed.expires_at,
      })
    }

    const { samples, cursor } = await pull(provider, access, { days })
    if (samples.length === 0) {
      return NextResponse.json({ ok: true, written: 0, note: "Nothing new in that window." })
    }

    // Idempotent on (user, provider, metric, recorded_at), so an overlapping
    // window is free and repairs any day that failed last time.
    const result = await convex.mutation(api.health.samples.ingest, {
      provider,
      samples,
      cursor,
    })

    return NextResponse.json({ ok: true, pulled: samples.length, ...result })
  } catch (error) {
    if (error instanceof PullError) {
      return NextResponse.json({ error: error.message }, { status: error.status })
    }
    console.error(`[health/sync/${provider}] failed:`, error)
    const message = error instanceof Error ? error.message : "Sync failed"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
