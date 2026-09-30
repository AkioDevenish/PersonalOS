/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeAll, beforeEach, describe, expect, test, vi } from "vitest"
import { SignJWT, exportJWK, exportPKCS8, generateKeyPair, type CryptoKey } from "jose"
import { api } from "./_generated/api"
import { BUNDLE_ID } from "./lib/app"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

/** Our own keys, for the deployment's sessions. */
let session: { JWT_PRIVATE_KEY: string; JWKS: string }
/** Keys standing in for Apple's, served from where Apple publishes them. */
let apple: { privateKey: CryptoKey; jwks: string }
/** A key Apple never published. */
let stranger: CryptoKey

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true })
  session = {
    JWT_PRIVATE_KEY: (await exportPKCS8(pair.privateKey)).trimEnd().replace(/\n/g, " "),
    JWKS: JSON.stringify({ keys: [{ use: "sig", ...(await exportJWK(pair.publicKey)) }] }),
  }
  const applePair = await generateKeyPair("RS256", { extractable: true })
  apple = {
    privateKey: applePair.privateKey,
    jwks: JSON.stringify({ keys: [{ kid: "apple-1", alg: "RS256", use: "sig", ...(await exportJWK(applePair.publicKey)) }] }),
  }
  stranger = (await generateKeyPair("RS256")).privateKey
})

beforeEach(() => {
  vi.stubEnv("JWT_PRIVATE_KEY", session.JWT_PRIVATE_KEY)
  vi.stubEnv("JWKS", session.JWKS)
  vi.stubEnv("CONVEX_SITE_URL", "https://example.convex.site")
  vi.stubEnv("SITE_URL", "personalos://")
  vi.stubGlobal("fetch", vi.fn(async (url: string | URL) => {
    if (String(url) === "https://appleid.apple.com/auth/keys") {
      return new Response(apple.jwks, { headers: { "content-type": "application/json" } })
    }
    return new Response("not found", { status: 404 })
  }))
})
afterEach(() => {
  vi.unstubAllEnvs()
  vi.unstubAllGlobals()
})

async function sha256Hex(text: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("")
}

type Claims = { sub?: string; email?: string; email_verified?: boolean | string; aud?: string; iss?: string }

/** A token the way Apple's sheet hands it to the phone, for a nonce the phone made up. */
async function identityToken(nonce: string, claims: Claims = {}, key: CryptoKey = apple.privateKey) {
  const { aud = BUNDLE_ID, iss = "https://appleid.apple.com", sub = "001234.apple.person", ...rest } = claims
  return await new SignJWT({ nonce: await sha256Hex(nonce), email: "person@privaterelay.appleid.com", email_verified: true, ...rest })
    .setProtectedHeader({ alg: "RS256", kid: "apple-1" })
    .setIssuer(iss)
    .setAudience(aud)
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime("10m")
    .sign(key)
}

async function signIn(t: ReturnType<typeof convexTest>, params: Record<string, string>) {
  return await t.action(api.auth.signIn, { provider: "apple-native", params })
}

describe("signing in with Apple on the phone", () => {
  test("a token Apple signed for this app starts a session, keeping the name the phone passed", async () => {
    const t = convexTest(schema, modules)
    const result = await signIn(t, { identityToken: await identityToken("n1"), nonce: "n1", name: "Ana Lee" })
    expect(typeof result.tokens?.token).toBe("string")
    const users = await t.run(async (ctx) => await ctx.db.query("users").collect())
    expect(users).toHaveLength(1)
    expect(users[0]).toMatchObject({ name: "Ana Lee", email: "person@privaterelay.appleid.com" })
  })

  test("signing in again finds the same person, even without a name", async () => {
    const t = convexTest(schema, modules)
    await signIn(t, { identityToken: await identityToken("n1"), nonce: "n1", name: "Ana Lee" })
    await signIn(t, { identityToken: await identityToken("n2"), nonce: "n2" })
    const users = await t.run(async (ctx) => await ctx.db.query("users").collect())
    expect(users).toHaveLength(1)
    expect(users[0].name).toBe("Ana Lee")
  })

  test("a token for another app is refused", async () => {
    const t = convexTest(schema, modules)
    await expect(signIn(t, {
      identityToken: await identityToken("n1", { aud: "com.someone.else" }), nonce: "n1",
    })).rejects.toThrow()
  })

  test("a token not signed by Apple is refused", async () => {
    const t = convexTest(schema, modules)
    await expect(signIn(t, {
      identityToken: await identityToken("n1", {}, stranger), nonce: "n1",
    })).rejects.toThrow()
  })

  test("a token from another issuer is refused", async () => {
    const t = convexTest(schema, modules)
    await expect(signIn(t, {
      identityToken: await identityToken("n1", { iss: "https://evil.example" }), nonce: "n1",
    })).rejects.toThrow()
  })

  test("a token replayed without the nonce it was made for is refused", async () => {
    const t = convexTest(schema, modules)
    await expect(signIn(t, { identityToken: await identityToken("n1"), nonce: "guess" })).rejects.toThrow()
    await expect(signIn(t, { identityToken: await identityToken("n1") })).rejects.toThrow()
  })

  test("joins an account that already proved it owns the address", async () => {
    const t = convexTest(schema, modules)
    const existing = await t.run(async (ctx) =>
      await ctx.db.insert("users", { email: "ana@example.com", emailVerificationTime: 1 }))
    await signIn(t, { identityToken: await identityToken("n1", { email: "Ana@Example.com" }), nonce: "n1" })
    const users = await t.run(async (ctx) => await ctx.db.query("users").collect())
    expect(users.map((u) => u._id)).toEqual([existing])
  })

  test("never joins an account that only claimed the address, like a password sign-up", async () => {
    const t = convexTest(schema, modules)
    await t.action(api.auth.signIn, {
      provider: "password",
      params: { email: "ana@example.com", password: "correct horse battery", flow: "signUp" },
    })
    await signIn(t, { identityToken: await identityToken("n1", { email: "ana@example.com" }), nonce: "n1" })
    expect(await t.run(async (ctx) => (await ctx.db.query("users").collect()).length)).toBe(2)
  })

  test("an address Apple has not verified joins nothing", async () => {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => await ctx.db.insert("users", { email: "ana@example.com", emailVerificationTime: 1 }))
    await signIn(t, {
      identityToken: await identityToken("n1", { email: "ana@example.com", email_verified: "false" }), nonce: "n1",
    })
    expect(await t.run(async (ctx) => (await ctx.db.query("users").collect()).length)).toBe(2)
  })
})
