/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, describe, expect, test, vi } from "vitest"
import { internal } from "./_generated/api"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")
const tester = () => convexTest(schema, modules)

afterEach(() => {
  vi.unstubAllEnvs()
  vi.useRealTimers()
})

const DAY = 24 * 60 * 60 * 1000

/** Apple telling us, after the fact, what happened to a purchase. */

async function subscribed(t: ReturnType<typeof tester>, expiresAt: number) {
  await t.run(async (ctx) => {
    await ctx.db.insert("entitlements", {
      userId: "user_1", subscription_status: "active", product_id: "os.personal.sub.monthly",
      expires_at: expiresAt, original_transaction_id: "orig_1", updated_at: 0,
    })
  })
}

async function entitlement(t: ReturnType<typeof tester>) {
  return await t.run(async (ctx) => (await ctx.db.query("entitlements").first())!)
}

describe("subscription notifications", () => {
  test("a renewal extends access", async () => {
    const t = tester()
    await subscribed(t, 1000)
    await t.mutation(internal.billing.entitlements.applyNotification, {
      type: "DID_RENEW", transactionId: "tx_2", originalTransactionId: "orig_1", expiresAt: 2000,
    })
    expect(await entitlement(t)).toMatchObject({ subscription_status: "active", expires_at: 2000 })
  })

  test("a refund takes access away straight away", async () => {
    const t = tester()
    await subscribed(t, Date.now() + 10 * DAY)
    await t.mutation(internal.billing.entitlements.applyNotification, {
      type: "REFUND", transactionId: "tx_1", originalTransactionId: "orig_1",
    })
    expect((await entitlement(t)).subscription_status).toBe("revoked")
  })

  test("a late notification about an earlier period changes nothing", async () => {
    const t = tester()
    await subscribed(t, 2000)
    await t.mutation(internal.billing.entitlements.applyNotification, {
      type: "EXPIRED", transactionId: "tx_1", originalTransactionId: "orig_1", expiresAt: 1000,
    })
    expect((await entitlement(t)).subscription_status).toBe("active")
    await t.mutation(internal.billing.entitlements.applyNotification, {
      type: "EXPIRED", transactionId: "tx_2", originalTransactionId: "orig_1", expiresAt: 2000,
    })
    expect((await entitlement(t)).subscription_status).toBe("expired")
  })

  test("a notification for somebody we have never seen is ignored", async () => {
    const t = tester()
    expect(
      await t.mutation(internal.billing.entitlements.applyNotification, {
        type: "DID_RENEW", transactionId: "tx_9", originalTransactionId: "orig_9", expiresAt: 5,
      }),
    ).toEqual({ applied: false })
  })
})

describe("article placement refunds", () => {
  async function placed(t: ReturnType<typeof tester>, liveUntil: number) {
    return await t.run(async (ctx) => {
      const article = await ctx.db.insert("articles", {
        authorToken: "author", authorId: "author", title: "Eat", category: "Food", summary: "",
        body: "", symbol: "leaf", colour: "green", minutes: 1, status: "published", flags: [],
        live_until: liveUntil, updated_at: 0,
      })
      await ctx.db.insert("article_payments", {
        articleId: article, authorToken: "author", transactionId: "tx_a",
        productId: "os.personal.article.30days", live_until: liveUntil, created_at: 0,
      })
      return article
    })
  }

  test("a refunded placement comes off Home, once", async () => {
    vi.useFakeTimers()
    const t = tester()
    const id = await placed(t, Date.now() + 20 * DAY)
    for (let i = 0; i < 2; i++) {
      await t.mutation(internal.billing.entitlements.applyNotification, { type: "REFUND", transactionId: "tx_a" })
    }
    const row = await t.run(async (ctx) => await ctx.db.get(id))
    expect(row!.status).toBe("expired")
    expect(row!.live_until).toBeUndefined()
    const payment = await t.run(async (ctx) => await ctx.db.query("article_payments").first())
    expect(payment!.refunded_at).toBeTypeOf("number")
  })

  test("refunding one of two placements keeps the other's time", async () => {
    vi.useFakeTimers()
    const t = tester()
    const until = Date.now() + 50 * DAY
    const id = await placed(t, until)
    await t.mutation(internal.billing.entitlements.applyNotification, { type: "REFUND", transactionId: "tx_a" })
    const row = await t.run(async (ctx) => await ctx.db.get(id))
    expect(row).toMatchObject({ status: "published", live_until: until - 30 * DAY })
  })
})

describe("the endpoint Apple posts to", () => {
  test("refuses anything that is not a signed notification", async () => {
    const t = tester()
    for (const body of ["not json", JSON.stringify({}), JSON.stringify({ signedPayload: "a.b.c" })]) {
      const response = await t.fetch("/appstore/notifications", { method: "POST", body })
      expect(response.status).toBe(400)
    }
  })
})
