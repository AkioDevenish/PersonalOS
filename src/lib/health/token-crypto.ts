import crypto from "crypto"

/**
 * Envelope encryption for provider OAuth tokens.
 *
 * A refresh token is a long-lived key to someone's health history, so it must
 * not sit in the database in the clear. Any Convex function can read any
 * document, which means a single over-broad query would otherwise leak every
 * user's tokens at once.
 *
 * The key lives only in the Next.js environment. Convex stores ciphertext it
 * has no way to read, so the blast radius of a bad query is nothing.
 *
 * AES-256-GCM: authenticated, so tampering fails loudly instead of decrypting
 * to garbage.
 */

const ALGORITHM = "aes-256-gcm"

function key(): Buffer {
  const raw = process.env.TOKEN_ENCRYPTION_KEY
  if (!raw) {
    throw new Error(
      "TOKEN_ENCRYPTION_KEY is not set. Generate one with: openssl rand -base64 32",
    )
  }
  const buf = Buffer.from(raw, "base64")
  if (buf.length !== 32) {
    throw new Error(
      `TOKEN_ENCRYPTION_KEY must decode to 32 bytes, got ${buf.length}. Generate one with: openssl rand -base64 32`,
    )
  }
  return buf
}

/** Returns `iv.ciphertext.tag`, all base64. */
export function encryptToken(plaintext: string): string {
  // 96-bit IV is the GCM standard, and must be unique per encryption
  const iv = crypto.randomBytes(12)
  const cipher = crypto.createCipheriv(ALGORITHM, key(), iv)
  const enc = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()])
  const tag = cipher.getAuthTag()
  return [iv.toString("base64"), enc.toString("base64"), tag.toString("base64")].join(".")
}

export function decryptToken(payload: string): string {
  const parts = payload.split(".")
  if (parts.length !== 3) throw new Error("Malformed encrypted token")

  const [iv, data, tag] = parts.map((p) => Buffer.from(p, "base64"))
  const decipher = crypto.createDecipheriv(ALGORITHM, key(), iv)
  decipher.setAuthTag(tag)
  // throws if the ciphertext or tag was altered
  return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf8")
}

export function hasEncryptionKey(): boolean {
  try {
    key()
    return true
  } catch {
    return false
  }
}
