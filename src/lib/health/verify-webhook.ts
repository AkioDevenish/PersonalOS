import crypto from "crypto"

/**
 * Webhook authenticity.
 *
 * A webhook endpoint that accepts a user identifier is the same privilege
 * escalation as trusting a client header — anyone who learns the URL can post
 * data into any account. The signature check is what makes the payload
 * trustworthy enough to resolve to a user at all, so it has to run before the
 * body is parsed for anything meaningful.
 */

/**
 * Recognised signature scheme prefixes. Kept to a known list rather than
 * "everything before the first =", because a base64 digest's own padding
 * would otherwise be mistaken for a prefix delimiter.
 */
const SCHEME_PREFIX = /^(sha1|sha256|sha512|hmac-sha256|v0|v1)=/i

/** Constant-time compare; plain !== leaks the match position through timing. */
function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a)
  const bb = Buffer.from(b)
  if (ab.length !== bb.length) return false
  return crypto.timingSafeEqual(ab, bb)
}

export type VerifyResult =
  | { ok: true }
  | { ok: false; status: number; error: string }

/**
 * HMAC over the raw body. Providers differ on digest encoding and on whether a
 * timestamp is part of the signed payload, so the shape is configurable —
 * `signedPayload` lets a provider that signs `${timestamp}.${body}` say so.
 */
export function verifyHmac({
  rawBody,
  signature,
  secret,
  encoding = "hex",
  algorithm = "sha256",
  timestamp,
  toleranceSeconds = 300,
}: {
  rawBody: string
  signature: string | null
  secret: string | undefined
  encoding?: "hex" | "base64"
  algorithm?: string
  timestamp?: string | null
  toleranceSeconds?: number
}): VerifyResult {
  if (!secret) {
    // Fail closed. An unset secret must never mean "accept everything".
    return { ok: false, status: 500, error: "Webhook secret not configured" }
  }
  if (!signature) {
    return { ok: false, status: 401, error: "Missing signature" }
  }

  // Replay protection, where the provider signs a timestamp: a captured
  // payload replayed later would otherwise still verify.
  if (timestamp) {
    const sent = Number(timestamp)
    if (!Number.isFinite(sent)) {
      return { ok: false, status: 401, error: "Invalid timestamp" }
    }
    const ageSeconds = Math.abs(Date.now() / 1000 - sent)
    if (ageSeconds > toleranceSeconds) {
      return { ok: false, status: 401, error: "Signature timestamp outside tolerance" }
    }
  }

  const signedPayload = timestamp ? `${timestamp}.${rawBody}` : rawBody
  const expected = crypto
    .createHmac(algorithm, secret)
    .update(signedPayload, "utf8")
    .digest(encoding as crypto.BinaryToTextEncoding)

  // Some providers prefix the scheme, e.g. "sha256=abc123".
  // Only strip a *recognised* prefix: base64 digests are padded with "=", so
  // splitting on "=" generally would truncate every base64 signature to "".
  const provided = signature.replace(SCHEME_PREFIX, "")

  if (!safeEqual(expected, provided)) {
    return { ok: false, status: 401, error: "Signature mismatch" }
  }

  return { ok: true }
}

/** Per-provider header names and secret env vars. */
export const WEBHOOK_CONFIG: Record<
  string,
  { signatureHeader: string; timestampHeader?: string; secretEnv: string; encoding?: "hex" | "base64" }
> = {
  oura: { signatureHeader: "x-oura-signature", secretEnv: "OURA_WEBHOOK_SECRET" },
  whoop: {
    signatureHeader: "x-whoop-signature",
    timestampHeader: "x-whoop-signature-timestamp",
    secretEnv: "WHOOP_WEBHOOK_SECRET",
    encoding: "base64",
  },
  fitbit: {
    signatureHeader: "x-fitbit-signature",
    secretEnv: "FITBIT_WEBHOOK_SECRET",
    encoding: "base64",
  },
  garmin: { signatureHeader: "x-garmin-signature", secretEnv: "GARMIN_WEBHOOK_SECRET" },
  withings: { signatureHeader: "x-withings-signature", secretEnv: "WITHINGS_WEBHOOK_SECRET" },
  // Aggregators — one integration instead of the six above
  terra: { signatureHeader: "terra-signature", timestampHeader: "terra-signature", secretEnv: "TERRA_WEBHOOK_SECRET" },
  vital: { signatureHeader: "svix-signature", timestampHeader: "svix-timestamp", secretEnv: "VITAL_WEBHOOK_SECRET" },
}
