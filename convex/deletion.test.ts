/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeAll, beforeEach, describe, expect, test, vi } from "vitest"
import { exportJWK, exportPKCS8, generateKeyPair } from "jose"
import { api } from "./_generated/api"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

let keys: { JWT_PRIVATE_KEY: string; JWKS: string }

beforeAll(async () => {
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

/** Deleting an account has to delete the account's data. */

/** Signs somebody up and hands back their id and an identity to act as. */
async function account(t: ReturnType<typeof convexTest>, email: string) {
  const result = (await t.action(api.auth.signIn, {
    provider: "password",
    params: { email, password: "a-long-enough-password", flow: "signUp" },
  })) as { tokens?: { token: string } }
  expect(result.tokens).toBeTruthy()

  const userId = await t.run(async (ctx) => {
    const user = await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("email"), email))
      .first()
    return user!._id
  })

  return {
    userId,
    identity: { subject: `${userId}|session_1`, tokenIdentifier: `https://x|${userId}|session_1` },
  }
}

/** Every table this test plants a row in, and how to count what is left. */
async function remaining(t: ReturnType<typeof convexTest>, userId: string) {
  return await t.run(async (ctx) => {
    const counts: Record<string, number> = {}
    for (const table of [
      "health_samples",
      "health_records",
      "ai_reports",
      "entitlements",
      "push_devices",
      "nutritionists",
      "finance_entries",
      "consults",
      "consult_messages",
      "cuisine_dishes",
    ] as const) {
      const rows = await ctx.db.query(table).collect()
      counts[table] = rows.filter(
        (row) => "userId" in row && (row as { userId: string }).userId === userId,
      ).length
    }
    // Messages hang off the consultation, so they are counted by what is left at all rather than by
    // whose they were.
    counts.consult_messages = (await ctx.db.query("consult_messages").collect()).length
    return counts
  })
}

describe("deleting an account", () => {
  test("takes the data with it", async () => {
    vi.useFakeTimers()
    const t = convexTest(schema, modules)
    const me = await account(t, "leaving@example.com")

    await t.run(async (ctx) => {
      // A year of steps, enough to need more than one batch of the sweep.
      for (let day = 0; day < 400; day++) {
        await ctx.db.insert("health_samples", {
          userId: me.userId, provider: "apple", metric: "steps", value: day, unit: "count",
          recorded_at: day, day: `2025-01-${day}`, ingested_at: day,
        })
      }
      await ctx.db.insert("health_records", { userId: me.userId, timestamp: 1, steps: 10 })
      await ctx.db.insert("ai_reports", {
        userId: me.userId, type: "endocrinologist", content: "You slept well.", created_at: 1,
      })
      await ctx.db.insert("entitlements", {
        userId: me.userId, subscription_status: "active", updated_at: 1,
      })
      await ctx.db.insert("push_devices", {
        userId: me.userId, token: "abc", platform: "ios", updated_at: 1,
      })
      await ctx.db.insert("finance_entries", {
        userId: me.userId, date: 1, minor: -100, currency: "USD",
        category: "Food", source: "manual", created_at: 1,
      })
      await ctx.db.insert("cuisine_dishes", {
        country: "TT", dish: "Doubles", key: "doubles", userId: me.userId, created_at: 1,
      })
      const consult = await ctx.db.insert("consults", {
        userId: me.userId, topic: "Sleep", status: "waiting", created_at: 1, updated_at: 1,
      })
      await ctx.db.insert("consult_messages", {
        consultId: consult, from: "user", authorId: me.userId, body: "Hello", created_at: 1,
      })
    })

    const before = await remaining(t, me.userId)
    expect(before.health_samples).toBe(400)
    expect(before.consult_messages).toBe(1)

    await t.withIdentity(me.identity).mutation(api.users.deleteAccount, {})
    await t.finishAllScheduledFunctions(vi.runAllTimers)

    const after = await remaining(t, me.userId)
    for (const [table, count] of Object.entries(after)) {
      expect(count, `${table} still has rows`).toBe(0)
    }
    vi.useRealTimers()
  })

  test("leaves other people alone", async () => {
    vi.useFakeTimers()
    const t = convexTest(schema, modules)
    const me = await account(t, "leaving2@example.com")
    const you = await account(t, "staying@example.com")

    await t.run(async (ctx) => {
      for (const userId of [me.userId, you.userId]) {
        await ctx.db.insert("health_records", { userId, timestamp: 1, steps: 10 })
        await ctx.db.insert("finance_entries", {
          userId, date: 1, minor: -100, currency: "USD",
          category: "Food", source: "manual", created_at: 1,
        })
      }
    })

    await t.withIdentity(me.identity).mutation(api.users.deleteAccount, {})
    await t.finishAllScheduledFunctions(vi.runAllTimers)

    expect((await remaining(t, me.userId)).health_records).toBe(0)
    const yours = await remaining(t, you.userId)
    expect(yours.health_records).toBe(1)
    expect(yours.finance_entries).toBe(1)
    vi.useRealTimers()
  })

  test("reaches what hangs off other things: photos, articles, long conversations", async () => {
    vi.useFakeTimers()
    const t = convexTest(schema, modules)
    const me = await account(t, "practitioner@example.com")
    const client = await account(t, "client@example.com")

    const planted = await t.run(async (ctx) => {
      const photo = await ctx.storage.store(new Blob(["face"]))
      await ctx.db.insert("nutritionists", {
        userId: me.userId, name: "Dr Me", country: "TT", credentials: "RD", bio: "",
        price_credits: 0, active: true, status: "approved", photo, updated_at: 1,
      })
      const article = await ctx.db.insert("articles", {
        authorToken: me.userId, authorId: me.userId, title: "Eat", category: "Food", summary: "",
        body: "", symbol: "leaf", colour: "green", minutes: 1, status: "published", flags: [],
        updated_at: 1,
      })
      await ctx.db.insert("article_payments", {
        articleId: article, authorToken: me.userId, transactionId: "tx_1",
        productId: "os.personal.article.30days", live_until: 2, created_at: 1,
      })
      // A conversation longer than one run of the sweep can delete.
      const mine = await ctx.db.insert("consults", {
        userId: me.userId, topic: "Sleep", status: "waiting", created_at: 1, updated_at: 1,
      })
      for (let i = 0; i < 1700; i++) {
        await ctx.db.insert("consult_messages", {
          consultId: mine, from: "you", authorId: me.userId, body: `${i}`, created_at: i,
        })
      }
      // One this person answered, which belongs to the client.
      const theirs = await ctx.db.insert("consults", {
        userId: client.userId, nutritionistId: me.userId, topic: "Diet", status: "answered",
        created_at: 1, updated_at: 1,
      })
      await ctx.db.insert("consult_messages", {
        consultId: theirs, from: "nutritionist", authorId: me.userId, body: "Eat greens", created_at: 1,
      })
      return { photo, theirs }
    })

    await t.withIdentity(me.identity).mutation(api.users.deleteAccount, {})
    await t.finishAllScheduledFunctions(vi.runAllTimers)

    await t.run(async (ctx) => {
      expect(await ctx.db.system.get(planted.photo)).toBeNull()
      expect(await ctx.db.query("nutritionists").take(10)).toHaveLength(0)
      expect(await ctx.db.query("articles").take(10)).toHaveLength(0)
      expect(await ctx.db.query("article_payments").take(10)).toHaveLength(0)

      const left = await ctx.db.query("consults").take(10)
      expect(left.map((c) => c._id)).toEqual([planted.theirs])
      expect(left[0].nutritionistId).toBeUndefined()
      expect(left[0].status).toBe("closed")
      // The client keeps the advice they were given; nothing of the deleted conversation is left.
      const messages = await ctx.db.query("consult_messages").take(10)
      expect(messages.map((m) => m.body)).toEqual(["Eat greens"])
    })
    vi.useRealTimers()
  })
})
