import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { oauthProvider, credentialsFor, redirectUriFor } from "@/lib/health/oauth-providers"
import { signState, safeReturnTo } from "@/lib/health/oauth-state"

export const dynamic = "force-dynamic"

/**
 * Begin an OAuth link.
 *
 * Redirects to the provider carrying a signed state parameter that names the
 * user who started it. The callback trusts that signature rather than any
 * session it happens to find, so a code cannot be redeemed into an account
 * that didn't ask for it.
 */
export async function GET(
  request: Request,
  { params }: { params: Promise<{ provider: string }> },
) {
  const { provider: key } = await params
  const { userId } = await auth()

  const origin = new URL(request.url).origin
  const back = (message: string) =>
    NextResponse.redirect(
      `${origin}/hub/connections?error=${encodeURIComponent(message)}`,
    )

  if (!userId) {
    return NextResponse.redirect(`${origin}/sign-in`)
  }

  const provider = oauthProvider(key)
  if (!provider) {
    return back(`${key} can't be connected this way`)
  }

  const creds = credentialsFor(provider)
  if (!creds) {
    // Not an error the user caused — say so plainly instead of a 500.
    return back(
      `${provider.label} isn't configured yet — ${provider.clientIdEnv} and ${provider.clientSecretEnv} need setting`,
    )
  }

  const returnTo = safeReturnTo(new URL(request.url).searchParams.get("returnTo"))

  let state: string
  try {
    state = signState({ userId, provider: key, returnTo })
  } catch {
    return back("Server is missing OAUTH_STATE_SECRET")
  }

  const authorize = new URL(provider.authorizeUrl)
  authorize.searchParams.set("response_type", "code")
  authorize.searchParams.set("client_id", creds.clientId)
  authorize.searchParams.set("redirect_uri", redirectUriFor(key, origin))
  authorize.searchParams.set("scope", provider.scopes.join(" "))
  authorize.searchParams.set("state", state)

  return NextResponse.redirect(authorize.toString())
}
