/**
 * OAuth2 configuration per cloud provider.
 *
 * Every provider here is the same authorization-code flow with different URLs,
 * so adding Fitbit or Whoop is a table entry rather than a new route. What
 * genuinely differs is how each one names the account we just linked, which is
 * what `fetchExternalUserId` is for — that id is the key a webhook later uses
 * to find the right Personal OS user.
 */

export type OAuthProvider = {
  key: string
  label: string
  authorizeUrl: string
  tokenUrl: string
  scopes: string[]
  clientIdEnv: string
  clientSecretEnv: string
  /** Some providers require Basic auth on the token exchange instead of body params. */
  tokenAuth: "body" | "basic"
  /** Resolve the provider's own user id, so webhooks can be routed back. */
  fetchExternalUserId: (accessToken: string) => Promise<string | null>
}

async function getJson(url: string, accessToken: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })
  if (!res.ok) return null
  return (await res.json().catch(() => null)) as Record<string, unknown> | null
}

export const OAUTH_PROVIDERS: Record<string, OAuthProvider> = {
  oura: {
    key: "oura",
    label: "Oura",
    authorizeUrl: "https://cloud.ouraring.com/oauth/authorize",
    tokenUrl: "https://api.ouraring.com/oauth/token",
    scopes: ["personal", "daily", "heartrate", "workout", "session"],
    clientIdEnv: "OURA_CLIENT_ID",
    clientSecretEnv: "OURA_CLIENT_SECRET",
    tokenAuth: "body",
    fetchExternalUserId: async (token) => {
      const me = await getJson("https://api.ouraring.com/v2/usercollection/personal_info", token)
      return (me?.id as string) ?? null
    },
  },

  fitbit: {
    key: "fitbit",
    label: "Fitbit",
    authorizeUrl: "https://www.fitbit.com/oauth2/authorize",
    tokenUrl: "https://api.fitbit.com/oauth2/token",
    scopes: ["activity", "heartrate", "sleep", "weight", "profile"],
    clientIdEnv: "FITBIT_CLIENT_ID",
    clientSecretEnv: "FITBIT_CLIENT_SECRET",
    tokenAuth: "basic",
    fetchExternalUserId: async (token) => {
      const me = await getJson("https://api.fitbit.com/1/user/-/profile.json", token)
      const user = me?.user as Record<string, unknown> | undefined
      return (user?.encodedId as string) ?? null
    },
  },

  whoop: {
    key: "whoop",
    label: "Whoop",
    authorizeUrl: "https://api.prod.whoop.com/oauth/oauth2/auth",
    tokenUrl: "https://api.prod.whoop.com/oauth/oauth2/token",
    scopes: ["read:recovery", "read:sleep", "read:workout", "read:profile", "offline"],
    clientIdEnv: "WHOOP_CLIENT_ID",
    clientSecretEnv: "WHOOP_CLIENT_SECRET",
    tokenAuth: "body",
    fetchExternalUserId: async (token) => {
      const me = await getJson("https://api.prod.whoop.com/developer/v1/user/profile/basic", token)
      const id = me?.user_id
      return id == null ? null : String(id)
    },
  },
}

export function oauthProvider(key: string): OAuthProvider | null {
  return OAUTH_PROVIDERS[key] ?? null
}

export type Credentials = { clientId: string; clientSecret: string }

/**
 * Returns null rather than throwing so the caller can send the user back with
 * an honest "this isn't set up yet" instead of a 500.
 */
export function credentialsFor(provider: OAuthProvider): Credentials | null {
  const clientId = process.env[provider.clientIdEnv]
  const clientSecret = process.env[provider.clientSecretEnv]
  if (!clientId || !clientSecret) return null
  return { clientId, clientSecret }
}

export function redirectUriFor(provider: string, origin: string): string {
  return `${origin}/api/health/oauth/${provider}/callback`
}
