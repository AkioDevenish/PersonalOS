/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import type { Id } from "./_generated/dataModel"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")
const tester = () => convexTest(schema, modules)
type Tester = ReturnType<typeof tester>

/** The ceilings that keep one account from filling a table everyone else reads. */

const CLIENT = { subject: "user_client", tokenIdentifier: "clerk|user_client" }
const DOCTOR = { subject: "user_doctor", tokenIdentifier: "clerk|user_doctor" }

beforeEach(() => vi.stubEnv("NUTRITIONIST_IDS", ""))
afterEach(() => {
  vi.unstubAllEnvs()
  vi.useRealTimers()
})

async function consult(t: Tester) {
  return await t.run(async (ctx) =>
    await ctx.db.insert("consults", {
      userId: CLIENT.subject, nutritionistId: DOCTOR.subject, topic: "Sleep", status: "waiting",
      payment_status: "paid", created_at: 1, updated_at: 1,
    }))
}

describe("call signalling", () => {
  test("only carries the four kinds of message a call uses", async () => {
    const t = tester()
    const id = await consult(t)
    await t.withIdentity(CLIENT).mutation(api.health.signal.post, { id, kind: "offer", payload: "v=0" })
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.signal.post, { id, kind: "spam" as "offer", payload: "" }),
    ).rejects.toThrow()
  })

  test("refuses a payload no call needs", async () => {
    const t = tester()
    const id = await consult(t)
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.signal.post, {
        id, kind: "candidate", payload: "x".repeat(40_000),
      }),
    ).rejects.toThrow("too large")
  })

  test("stops accepting once a session has more than any call could need", async () => {
    const t = tester()
    const id = await consult(t)
    await t.run(async (ctx) => {
      for (let i = 0; i < 500; i++) {
        await ctx.db.insert("call_signals", {
          consultId: id, from: DOCTOR.subject, kind: "candidate", payload: "c", created_at: i,
        })
      }
    })
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.signal.post, { id, kind: "bye", payload: "" }),
    ).rejects.toThrow("Too many attempts")
  })

  test("old signalling is swept away and recent signalling stays", async () => {
    vi.useFakeTimers()
    const t = tester()
    const id = await consult(t)
    await t.withIdentity(CLIENT).mutation(api.health.signal.post, { id, kind: "offer", payload: "old" })
    vi.advanceTimersByTime(2 * 24 * 60 * 60 * 1000)
    await t.withIdentity(CLIENT).mutation(api.health.signal.post, { id, kind: "offer", payload: "new" })

    await t.mutation(internal.health.signal.sweep, {})
    const left = await t.run(async (ctx) => await ctx.db.query("call_signals").take(10))
    expect(left.map((r) => r.payload)).toEqual(["new"])
  })
})

describe("a conversation", () => {
  test("sends its most recent messages, oldest of those first", async () => {
    const t = tester()
    const id = await consult(t)
    await t.run(async (ctx) => {
      for (let i = 0; i < 320; i++) {
        await ctx.db.insert("consult_messages", {
          consultId: id, from: "you", authorId: CLIENT.subject, body: `${i}`, created_at: i,
        })
      }
    })
    const thread = await t.withIdentity(CLIENT).query(api.health.consult.thread, { id })
    expect(thread.messages).toHaveLength(300)
    expect(thread.messages[0].body).toBe("20")
    expect(thread.messages.at(-1)!.body).toBe("319")
  })
})

describe("a practitioner's profile", () => {
  const application = {
    name: "Dr Doctor", country: "TT", credentials: "RD", bio: "Hello", specialties: ["Sleep"],
    offers_video: false, price_minor: 4000, currency: "TTD", active: true,
  }

  async function approved(t: Tester) {
    await t.withIdentity(DOCTOR).mutation(api.health.consult.apply, application)
    await t.run(async (ctx) => {
      const row = await ctx.db
        .query("nutritionists")
        .withIndex("by_user", (q) => q.eq("userId", DOCTOR.subject))
        .first()
      await ctx.db.patch(row!._id, { status: "approved" })
    })
  }

  test("goes back to review when the qualifications or name change", async () => {
    const t = tester()
    await approved(t)
    expect(
      await t.withIdentity(DOCTOR).mutation(api.health.consult.apply, { ...application, bio: "New bio" }),
    ).toEqual({ status: "approved" })
    expect(
      await t.withIdentity(DOCTOR).mutation(api.health.consult.apply, { ...application, credentials: "MD" }),
    ).toEqual({ status: "pending" })
    expect(await t.withIdentity(CLIENT).query(api.health.consult.directory, {})).toEqual([])
  })

  test("goes back to review on a new photograph, and the old one is deleted", async () => {
    const t = tester()
    const [first, second] = await t.run(async (ctx) => [
      await ctx.storage.store(new Blob(["a"])),
      await ctx.storage.store(new Blob(["b"])),
    ])
    await t.withIdentity(DOCTOR).mutation(api.health.consult.apply, { ...application, photo: first })
    await approved(t)
    expect(
      await t.withIdentity(DOCTOR).mutation(api.health.consult.apply, { ...application, photo: second }),
    ).toEqual({ status: "pending" })
    expect(await t.run(async (ctx) => await ctx.db.system.get(first as Id<"_storage">))).toBeNull()
  })

  test("has a length limit on every field", async () => {
    const t = tester()
    for (const change of [
      { name: "x".repeat(81) },
      { credentials: "x".repeat(201) },
      { bio: "x".repeat(1501) },
      { specialties: ["x".repeat(41)] },
    ]) {
      await expect(
        t.withIdentity(DOCTOR).mutation(api.health.consult.apply, { ...application, ...change }),
      ).rejects.toThrow()
    }
  })

  test("the directory lists approved practitioners only, most recently around first", async () => {
    const t = tester()
    await t.run(async (ctx) => {
      const base = {
        country: "TT", credentials: "RD", bio: "", price_credits: 0, active: true, updated_at: 0,
      }
      await ctx.db.insert("nutritionists", { ...base, userId: "a", name: "Away", status: "approved", last_seen: 1 })
      await ctx.db.insert("nutritionists", { ...base, userId: "b", name: "Here", status: "approved", last_seen: 9 })
      await ctx.db.insert("nutritionists", { ...base, userId: "c", name: "Waiting", status: "pending", last_seen: 99 })
      await ctx.db.insert("nutritionists", { ...base, userId: "d", name: "Off", status: "approved", active: false })
    })
    const listed = await t.withIdentity(CLIENT).query(api.health.consult.directory, {})
    expect(listed.map((r) => r.name)).toEqual(["Here", "Away"])
  })
})

describe("cuisine suggestions", () => {
  test("need a real country code and a real dish name", async () => {
    const t = tester()
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.cuisine.suggest, { country: "tt", dish: "Doubles" }),
    ).rejects.toThrow("Not a country code")
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.cuisine.suggest, { country: "TT", dish: "visit www.spam.test" }),
    ).rejects.toThrow("doesn't look like a dish")
    await expect(
      t.withIdentity(CLIENT).query(api.health.cuisine.forCountry, { country: "Trinidad" }),
    ).rejects.toThrow("Not a country code")
  })

  test("one person can only name so many dishes in a country", async () => {
    const t = tester()
    for (let i = 0; i < 60; i++) {
      await t.withIdentity(CLIENT).mutation(api.health.cuisine.suggest, { country: "TT", dish: `Dish ${i}` })
    }
    await expect(
      t.withIdentity(CLIENT).mutation(api.health.cuisine.suggest, { country: "TT", dish: "One more" }),
    ).rejects.toThrow("as many dishes")
    // Taking a vote back is always allowed.
    expect(
      await t.withIdentity(CLIENT).mutation(api.health.cuisine.suggest, { country: "TT", dish: "Dish 0" }),
    ).toEqual({ added: false })
  })
})
