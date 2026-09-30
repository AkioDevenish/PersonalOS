import { createRemoteJWKSet, jwtVerify } from "jose"
import { BUNDLE_ID } from "./app"

/** Signing in with Apple's own sheet on the phone, which hands the app a token Apple signed. */

const ISSUER = "https://appleid.apple.com"
const keys = createRemoteJWKSet(new URL(`${ISSUER}/auth/keys`))

export type AppleIdentity = {
  /** Apple's stable id for this person, the same across every sign-in. */
  sub: string
  email?: string
  emailVerified: boolean
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("")
}

/**
 * Who an identity token says is signing in, once its signature, issuer, audience, expiry and nonce
 * all check out. The phone asks Apple with the SHA-256 of a one-off nonce and sends the nonce
 * itself here, so a token lifted from somewhere else cannot be replayed without it.
 */
export async function verifyAppleIdentityToken(token: string, nonce: string): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(token, keys, { issuer: ISSUER, audience: BUNDLE_ID })
  if (typeof payload.sub !== "string" || !payload.sub) throw new Error("Apple sign-in had no account")
  if (payload.nonce !== (await sha256Hex(nonce))) throw new Error("Apple sign-in did not match this request")
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : undefined
  // Apple sends this as either a boolean or the string "true".
  const verified = payload.email_verified === true || payload.email_verified === "true"
  return { sub: payload.sub, email, emailVerified: Boolean(email) && verified }
}
