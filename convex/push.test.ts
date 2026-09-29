/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

const ME = { subject: "user_me", tokenIdentifier: "clerk|user_me" }
const THEM = { subject: "user_them", tokenIdentifier: "clerk|user_them" }
const TOKEN = "a".repeat(64)

beforeEach(() => {
  // No APNs key: exactly the state the deployment is in until the paid account exists, and the
  // state every one of these tests runs in.
  vi.stubEnv("APNS_KEY_ID", "")
  vi.stubEnv("APNS_TEAM_ID", "")
  vi.stubEnv("APNS_P8", "")
  vi.useFakeTimers()
})
afterEach(() => {
  vi.unstubAllEnvs()
  vi.useRealTimers()
})

describe("devices", () => {
  test("a device is registered once, however many times the app launches", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(ME).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    await t.withIdentity(ME).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    expect(await t.query(internal.devices.forUser, { userId: ME.subject })).toEqual([TOKEN])
  })

  test("a phone that changes hands stops getting the last person's pushes", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(ME).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    await t.withIdentity(THEM).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    expect(await t.query(internal.devices.forUser, { userId: ME.subject })).toEqual([])
    expect(await t.query(internal.devices.forUser, { userId: THEM.subject })).toEqual([TOKEN])
  })

  test("signing out only removes your own device", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(ME).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    await t.withIdentity(THEM).mutation(api.devices.unregister, { token: TOKEN })
    expect(await t.query(internal.devices.forUser, { userId: ME.subject })).toEqual([TOKEN])
    await t.withIdentity(ME).mutation(api.devices.unregister, { token: TOKEN })
    expect(await t.query(internal.devices.forUser, { userId: ME.subject })).toEqual([])
  })

  test("a token cannot be registered without signing in, or made up", async () => {
    const t = convexTest(schema, modules)
    await expect(t.mutation(api.devices.register, { token: TOKEN, platform: "ios" }))
      .rejects.toThrow("Not authenticated")
    await expect(t.withIdentity(ME).mutation(api.devices.register, { token: "short", platform: "ios" }))
      .rejects.toThrow("not a device token")
  })

  test("with no APNs key, sending is skipped rather than failing", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(ME).mutation(api.devices.register, { token: TOKEN, platform: "ios" })
    const result = await t.action(internal.push.send, {
      userId: ME.subject, title: "Spoonful", body: "Your practitioner has replied.",
    })
    expect(result).toEqual({ delivered: 0, forgotten: 0, skipped: true })
  })
})

describe("a reply still lands when push cannot", () => {
  test("the message is saved and the queued push does not throw", async () => {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => {
      await ctx.db.insert("nutritionists", {
        userId: THEM.subject, name: "Dr Them", country: "TT", credentials: "RD",
        bio: "", price_credits: 0, active: true, status: "approved", updated_at: 0,
      })
    })
    const opened = await t.withIdentity(ME).mutation(api.health.consult.openSession, {
      specialistId: THEM.subject, kind: "text",
    })
    await t.withIdentity(ME).mutation(api.health.consult.send, { id: opened.id, body: "Is this normal?" })

    // Runs the push the reply queued.
    await t.finishAllScheduledFunctions(vi.runAllTimers)

    const thread = await t.withIdentity(ME).query(api.health.consult.thread, { id: opened.id })
    expect(thread.messages).toHaveLength(1)
    expect(thread.messages[0].body).toBe("Is this normal?")
  })
})
