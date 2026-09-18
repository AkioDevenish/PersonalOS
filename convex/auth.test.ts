/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeAll, beforeEach, describe, expect, test, vi } from "vitest"
import { exportJWK, exportPKCS8, generateKeyPair } from "jose"
import { api } from "./_generated/api"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

let keys: { JWT_PRIVATE_KEY: string; JWKS: string }

beforeAll(async () => {
  // Real keys, made the way the deployment's are, so the tokens these tests
  // get are the same kind the phone will carry.
  const pair = await generateKeyPair("RS256", { extractable: true })
  const priv = await exportPKCS8(pair.privateKey)
  const pub = await exportJWK(pair.publicKey)
  keys = {
    JWT_PRIVATE_KEY: priv.trimEnd().replace(/\n/g, " "),
    JWKS: JSON.stringify({ keys: [{ use: "sig", ...pub }] }),
  }
})

beforeEach(() => {
  vi.stubEnv("JWT_PRIVATE_KEY", keys.JWT_PRIVATE_KEY)
  vi.stubEnv("JWKS", keys.JWKS)
  vi.stubEnv("CONVEX_SITE_URL", "https://example.convex.site")
  vi.stubEnv("SITE_URL", "personalos://")
})
afterEach(() => vi.unstubAllEnvs())

const email = "Someone@Example.com"
const password = "correct horse battery"

async function signUp(t: ReturnType<typeof convexTest>) {
  return await t.action(api.auth.signIn, {
    provider: "password",
    params: { email, password, flow: "signUp", name: "Someone" },
  })
}

describe("email and password", () => {
  test("signing up returns a token and a refresh token", async () => {
    const t = convexTest(schema, modules)
    const result: any = await signUp(t)
    expect(typeof result.tokens?.token).toBe("string")
    expect(typeof result.tokens?.refreshToken).toBe("string")
  })

  test("signing in again with the same password works, and the email is not case-sensitive", async () => {
    const t = convexTest(schema, modules)
    await signUp(t)
    const result: any = await t.action(api.auth.signIn, {
      provider: "password",
      params: { email: "someone@example.com", password, flow: "signIn" },
    })
    expect(typeof result.tokens?.token).toBe("string")
  })

  test("the wrong password is refused", async () => {
    const t = convexTest(schema, modules)
    await signUp(t)
    await expect(t.action(api.auth.signIn, {
      provider: "password",
      params: { email, password: "not the password", flow: "signIn" },
    })).rejects.toThrow()
  })

  test("a short password is refused at sign-up", async () => {
    const t = convexTest(schema, modules)
    await expect(t.action(api.auth.signIn, {
      provider: "password",
      params: { email: "new@example.com", password: "short", flow: "signUp" },
    })).rejects.toThrow("Use at least 8 characters")
  })

  test("a refresh token buys a fresh session token", async () => {
    const t = convexTest(schema, modules)
    const first: any = await signUp(t)
    const refreshed: any = await t.action(api.auth.signIn, { refreshToken: first.tokens.refreshToken })
    expect(typeof refreshed.tokens?.token).toBe("string")
  })

  test("only the app is accepted as a place to return to", async () => {
    const { safeRedirect } = await import("./auth")
    expect(safeRedirect("personalos://auth")).toBe("personalos://auth")
    expect(() => safeRedirect("https://evil.example/steal")).toThrow("only return to the app")
    expect(() => safeRedirect("http://personalos.example")).toThrow()
  })
})
