import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { oauthProvider, credentialsFor, redirectUriFor } from "@/lib/health/oauth-providers"
import { signState } from "@/lib/health/oauth-state"

export const dynamic = "force-dynamic"

/**
 * App-driven start of an OAuth link.
 *
 * The old /start route derived the user from a web session and redirected the
 * browser — it existed for a web dashboard that is gone. A phone can't do
 * that: an in-app browser opens a URL cold, with no session and no custom
 * headers. So the app calls this first with its own Clerk bearer token, gets
 * back the provider's authorize URL with the user already sealed inside the
 * signed state, and opens that URL in the system browser. The callback then
 * trusts the state signature, never a session.
 */
export async function POST(
  request: Request,
  { params }: { params: Promise<{ provider: string }> },
) {
  const { provider: key } = await params
  const { userId } = await auth()

  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const provider = oauthProvider(key)
  if (!provider) {
    return NextResponse.json({ error: `${key} can't be connected this way` }, { status: 404 })
  }

  const creds = credentialsFor(provider)
  if (!creds) {
    return NextResponse.json(
      {
        error: `${provider.label} isn't configured yet — ${provider.clientIdEnv} and ${provider.clientSecretEnv} need setting`,
      },
      { status: 503 },
    )
  }

  let state: string
  try {
    state = signState({ userId, provider: key, returnTo: "" })
  } catch {
    return NextResponse.json({ error: "Server is missing OAUTH_STATE_SECRET" }, { status: 500 })
  }

  const origin = new URL(request.url).origin
  const authorize = new URL(provider.authorizeUrl)
  authorize.searchParams.set("response_type", "code")
  authorize.searchParams.set("client_id", creds.clientId)
  authorize.searchParams.set("redirect_uri", redirectUriFor(key, origin))
  authorize.searchParams.set("scope", provider.scopes.join(" "))
  authorize.searchParams.set("state", state)

  return NextResponse.json({ url: authorize.toString() })
}
