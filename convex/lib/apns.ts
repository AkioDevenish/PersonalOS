/** What Apple's push service says back, read without Node so it can be tested anywhere. */

const HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
} as const

/**
 * Where to send, which has to be said outright: a token from an App Store build is "bad" to the
 * sandbox host, so guessing wrong would make every phone look uninstalled.
 */
export function apnsHost(environment: string | undefined): string | null {
  if (environment === "production" || environment === "sandbox") return HOSTS[environment]
  return null
}

/**
 * Whether Apple is saying this token will never work again. Any other failure, a bad payload or an
 * expired key included, is ours to fix and no reason to forget somebody's phone.
 */
export function isGone(status: number, body: string): boolean {
  if (status === 410) return true
  if (status !== 400) return false
  try {
    const reason = (JSON.parse(body) as { reason?: string }).reason
    return reason === "BadDeviceToken" || reason === "Unregistered"
  } catch {
    return false
  }
}
