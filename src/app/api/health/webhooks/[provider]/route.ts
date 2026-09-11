import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { verifyHmac, WEBHOOK_CONFIG } from "@/lib/health/verify-webhook"
import { internal } from "../../../../../../convex/_generated/api"

/**
 * Cloud-provider webhooks.
 *
 * The chain that makes this safe, in order:
 *
 *   1. verify the HMAC over the *raw* body — before trusting any field in it
 *   2. resolve the provider's account id to a Personal OS user via the
 *      mapping stored at connect time
 *   3. only then write, through the internal mutation
 *
 * Step 2 is the part that cannot be skipped. The payload names the user in the
 * provider's own namespace; taking that as our user id would let anyone who
 * forged step 1 write into any account.
 */

type Params = Promise<{ provider: string }>

export async function POST(request: Request, { params }: { params: Params }) {
  const { provider } = await params

  const config = WEBHOOK_CONFIG[provider]
  if (!config) {
    return NextResponse.json(
      { success: false, error: `No webhook configured for "${provider}"` },
      { status: 404 },
    )
  }

  // Must read the body as raw text: re-serialising parsed JSON changes bytes
  // (key order, whitespace) and the signature would never match.
  const rawBody = await request.text()

  const verified = verifyHmac({
    rawBody,
    signature: request.headers.get(config.signatureHeader),
    timestamp: config.timestampHeader
      ? request.headers.get(config.timestampHeader)
      : undefined,
    secret: process.env[config.secretEnv],
    encoding: config.encoding,
  })

  if (!verified.ok) {
    return NextResponse.json(
      { success: false, error: verified.error },
      { status: verified.status },
    )
  }

  let payload: {
    external_user_id?: string
    provider?: string
    samples?: unknown[]
    timeZone?: string
    cursor?: string
  }
  try {
    payload = JSON.parse(rawBody)
  } catch {
    return NextResponse.json({ success: false, error: "Malformed JSON" }, { status: 400 })
  }

  const externalUserId = payload.external_user_id
  if (!externalUserId) {
    return NextResponse.json(
      { success: false, error: "Payload missing external_user_id" },
      { status: 400 },
    )
  }

  try {
    const convex = getConvexClient()

    const connection = await convex.query(internal.health.connections.byExternalUser, {
      external_user_id: externalUserId,
    })

    // Unknown account: 200, not an error. Providers retry non-2xx with
    // backoff and eventually disable the subscription — a user who
    // disconnected here shouldn't cost us the whole webhook endpoint.
    if (!connection) {
      return NextResponse.json({ success: true, ignored: "unknown external user" })
    }

    const samples = Array.isArray(payload.samples) ? payload.samples : []
    if (samples.length === 0) {
      return NextResponse.json({ success: true, inserted: 0, updated: 0 })
    }

    const result = await convex.mutation(internal.health.samples.ingestForUser, {
      userId: connection.userId,
      // trust our own record of which provider this connection is, not the body
      provider: connection.provider,
      samples,
      timeZone: payload.timeZone,
      cursor: payload.cursor,
    })

    return NextResponse.json({ success: true, ...result })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Webhook processing failed"
    return NextResponse.json({ success: false, error: message }, { status: 500 })
  }
}

/**
 * Several providers verify a subscription by GETting it with a challenge that
 * must be echoed back.
 */
export async function GET(request: Request) {
  const url = new URL(request.url)
  const challenge =
    url.searchParams.get("challenge") ??
    url.searchParams.get("verify") ??
    url.searchParams.get("hub.challenge")

  if (challenge) return new Response(challenge, { status: 200 })
  return NextResponse.json({ ok: true })
}
