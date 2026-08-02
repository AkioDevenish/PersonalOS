import crypto from "crypto"

/**
 * The OAuth `state` parameter.
 *
 * Without it, an attacker can send a victim to a callback URL carrying the
 * attacker's authorization code, silently linking the attacker's Oura account
 * to the victim's ledger — or the reverse. State makes the callback prove it
 * belongs to the redirect this server issued.
 *
 * Signed rather than stored: an HMAC over (user, provider, nonce, issued-at)
 * needs no session table and survives a serverless instance disappearing
 * between the redirect and the callback.
 */

const MAX_AGE_SECONDS = 10 * 60

function secret(): string {
  const value = process.env.OAUTH_STATE_SECRET || process.env.CLERK_SECRET_KEY
  if (!value) {
    // Fail closed. Signing with a fallback constant would make every
    // deployment forgeable by anyone who reads the source.
    throw new Error("OAUTH_STATE_SECRET is not configured")
  }
  return value
}

function b64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")
}

function fromB64url(input: string): Buffer {
  return Buffer.from(input.replace(/-/g, "+").replace(/_/g, "/"), "base64")
}

export type StatePayload = {
  userId: string
  provider: string
  /** Where to send the browser once the link completes. */
  returnTo: string
}

export function signState(payload: StatePayload): string {
  const body = {
    ...payload,
    n: crypto.randomBytes(8).toString("hex"),
    t: Math.floor(Date.now() / 1000),
  }
  const encoded = b64url(JSON.stringify(body))
  const mac = b64url(crypto.createHmac("sha256", secret()).update(encoded).digest())
  return `${encoded}.${mac}`
}

export type VerifyResult =
  | { ok: true; payload: StatePayload }
  | { ok: false; error: string }

export function verifyState(state: string | null): VerifyResult {
  if (!state) return { ok: false, error: "Missing state" }

  const parts = state.split(".")
  if (parts.length !== 2) return { ok: false, error: "Malformed state" }
  const [encoded, mac] = parts

  const expected = b64url(crypto.createHmac("sha256", secret()).update(encoded).digest())
  const a = Buffer.from(mac)
  const b = Buffer.from(expected)
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { ok: false, error: "State signature mismatch" }
  }

  let body: StatePayload & { t?: number }
  try {
    body = JSON.parse(fromB64url(encoded).toString("utf8"))
  } catch {
    return { ok: false, error: "Unreadable state" }
  }

  // A signed state is valid forever otherwise, so a leaked redirect URL could
  // be replayed months later.
  const age = Math.floor(Date.now() / 1000) - (body.t ?? 0)
  if (!Number.isFinite(age) || age < 0 || age > MAX_AGE_SECONDS) {
    return { ok: false, error: "State expired" }
  }

  if (!body.userId || !body.provider) {
    return { ok: false, error: "Incomplete state" }
  }

  return {
    ok: true,
    payload: { userId: body.userId, provider: body.provider, returnTo: body.returnTo },
  }
}

/**
 * Only ever redirect to our own paths. Echoing an arbitrary `returnTo` back
 * into a Location header is an open redirect, which is exactly the primitive
 * phishing wants.
 */
export function safeReturnTo(value: string | undefined | null): string {
  if (!value) return "/hub/connections"
  if (!value.startsWith("/") || value.startsWith("//")) return "/hub/connections"
  return value
}
