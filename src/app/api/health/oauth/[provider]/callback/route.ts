import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { internal } from "../../../../../../../convex/_generated/api"
import { oauthProvider, credentialsFor, redirectUriFor } from "@/lib/health/oauth-providers"
import { verifyState } from "@/lib/health/oauth-state"
import { encryptToken } from "@/lib/health/token-crypto"

export const dynamic = "force-dynamic"

/**
 * Complete an OAuth link.
 *
 * This lands in a browser the provider redirected to — there is no web app to
 * return to, so the response is a self-contained scrap of HTML that bounces
 * back into the phone app via its personalos:// scheme, with a plain-text
 * fallback telling the user to switch back by hand.
 *
 * Order matters here:
 *
 *   1. verify the signed state — it names the user, and nothing else may
 *   2. exchange the code for tokens
 *   3. ask the provider who this account is, so webhooks can be routed later
 *   4. store the tokens encrypted, then mark the connection live
 *
 * The user is taken from the state signature rather than the current session.
 * Reading the session instead would let someone finish a link in whichever
 * account happened to be logged in on that browser.
 */
export async function GET(
  request: Request,
  { params }: { params: Promise<{ provider: string }> },
) {
  const { provider: key } = await params
  const url = new URL(request.url)
  const origin = url.origin

  const page = (heading: string, body: string, deepLink: string) =>
    new NextResponse(
      `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
        `<meta http-equiv="refresh" content="0;url=${deepLink}">` +
        `<title>${heading}</title>` +
        `<body style="font-family:-apple-system,system-ui;background:#F2EDE3;color:#28200F;display:grid;place-items:center;min-height:90vh;text-align:center;padding:24px">` +
        `<div><h1 style="font-weight:500">${heading}</h1><p style="color:#6E5D45;max-width:28rem">${body}</p>` +
        `<p style="color:#A8957E;font-size:13px">You can close this window and return to the Personal OS app.</p></div>`,
      { headers: { "Content-Type": "text/html; charset=utf-8" } },
    )

  const fail = (message: string) =>
    page("That didn\u2019t work", message, `personalos://connected?error=${encodeURIComponent(message)}`)

  // The user declined on the provider's screen — not an error worth shouting about.
  const denied = url.searchParams.get("error")
  if (denied) {
    return page("Connection cancelled", "Nothing was linked.", "personalos://connected?cancelled=1")
  }

  const provider = oauthProvider(key)
  if (!provider) return fail("Unknown provider")

  const verified = verifyState(url.searchParams.get("state"))
  if (!verified.ok) return fail(`Could not verify that link attempt (${verified.error})`)

  const { userId } = verified.payload
  // the state also names the provider; don't let the path disagree with it
  if (verified.payload.provider !== key) return fail("Provider mismatch")

  const code = url.searchParams.get("code")
  if (!code) return fail("No authorization code returned")

  const creds = credentialsFor(provider)
  if (!creds) return fail(`${provider.label} isn't configured`)

  try {
    // --- exchange ---
    const body = new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUriFor(key, origin),
    })
    const headers: Record<string, string> = {
      "Content-Type": "application/x-www-form-urlencoded",
    }

    if (provider.tokenAuth === "basic") {
      headers.Authorization =
        "Basic " + Buffer.from(`${creds.clientId}:${creds.clientSecret}`).toString("base64")
    } else {
      body.set("client_id", creds.clientId)
      body.set("client_secret", creds.clientSecret)
    }

    const tokenRes = await fetch(provider.tokenUrl, { method: "POST", headers, body })
    const tokens = (await tokenRes.json().catch(() => null)) as {
      access_token?: string
      refresh_token?: string
      expires_in?: number
      scope?: string
    } | null

    if (!tokenRes.ok || !tokens?.access_token) {
      // Deliberately vague to the user; the detail goes to the server log.
      console.error(`[oauth:${key}] token exchange failed`, tokenRes.status, tokens)
      return fail(`${provider.label} rejected the connection`)
    }

    // --- identify ---
    // Without this a webhook has no way to map its payload back to a user.
    const externalUserId = await provider.fetchExternalUserId(tokens.access_token)

    // --- persist ---
    const convex = getConvexClient()

    await convex.mutation(internal.health.tokens.store, {
      userId,
      provider: key,
      access_token: encryptToken(tokens.access_token),
      refresh_token: tokens.refresh_token ? encryptToken(tokens.refresh_token) : undefined,
      expires_at: tokens.expires_in ? Date.now() + tokens.expires_in * 1000 : undefined,
      scopes: tokens.scope ? tokens.scope.split(/[\s,]+/).filter(Boolean) : provider.scopes,
    })

    await convex.mutation(internal.health.connections.linkForUser, {
      userId,
      provider: key,
      external_user_id: externalUserId ?? undefined,
      scopes: tokens.scope ? tokens.scope.split(/[\s,]+/).filter(Boolean) : provider.scopes,
    })

    return page(
      "You\u2019re connected",
      `${provider.label} is linked. Data will start arriving shortly.`,
      `personalos://connected?connected=${key}`,
    )
  } catch (error) {
    console.error(`[oauth:${key}] callback failed`, error)
    const message =
      error instanceof Error && /TOKEN_ENCRYPTION_KEY/.test(error.message)
        ? "Server is missing TOKEN_ENCRYPTION_KEY"
        : `Could not finish connecting ${provider.label}`
    return fail(message)
  }
}
