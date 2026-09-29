/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

const ME = { subject: "user_me", tokenIdentifier: "clerk|user_me" }
const OTHER = { subject: "user_other", tokenIdentifier: "clerk|user_other" }

const DAY = 24 * 60 * 60 * 1000

afterEach(() => vi.useRealTimers())

function verified(overrides: Partial<{
  userId: string; verifiedTransactionId: string; productId: string; expiresAt: number
}> = {}) {
  return {
    userId: ME.subject,
    verifiedTransactionId: "tx_1",
    productId: "os.personal.sub.monthly",
    expiresAt: Date.now() + 30 * DAY,
    originalTransactionId: "otx_1",
    ...overrides,
  }
}

describe("what the app is told", () => {
  test("nobody has anything until they buy", async () => {
    const t = convexTest(schema, modules)
    expect(await t.withIdentity(ME).query(api.billing.entitlements.mine, {})).toEqual({
      subscription_status: "none", product_id: undefined, expires_at: undefined,
    })
  })

  test("a verified purchase makes the subscription active", async () => {
    const t = convexTest(schema, modules)
    const args = verified()
    expect(await t.mutation(internal.billing.entitlements.applyVerified, args)).toEqual({ applied: true })
    expect(await t.withIdentity(ME).query(api.billing.entitlements.mine, {})).toEqual({
      subscription_status: "active",
      product_id: "os.personal.sub.monthly",
      expires_at: args.expiresAt,
    })
  })

  test("a subscription that ran out while the app was closed reads as expired", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt: Date.now() - 1 }))
    const mine = await t.withIdentity(ME).query(api.billing.entitlements.mine, {})
    expect(mine.subscription_status).toBe("expired")
  })

  test("one person's subscription is not another's", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified())
    const theirs = await t.withIdentity(OTHER).query(api.billing.entitlements.mine, {})
    expect(theirs.subscription_status).toBe("none")
    expect(await t.withIdentity(OTHER).query(api.billing.entitlements.subscribed, { now: Date.now() }))
      .toBe(false)
  })

  test("needs a signed-in user", async () => {
    const t = convexTest(schema, modules)
    await expect(t.query(api.billing.entitlements.mine, {})).rejects.toThrow("Not authenticated")
    expect(await t.query(api.billing.entitlements.subscribed, { now: Date.now() })).toBe(false)
  })
})

describe("applying a purchase", () => {
  test("the same transaction applied twice counts once", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified())
    expect(await t.mutation(internal.billing.entitlements.applyVerified, verified()))
      .toEqual({ applied: false, reason: "already applied" })

    await t.run(async (ctx) => {
      expect(await ctx.db.query("entitlements").collect()).toHaveLength(1)
      expect(await ctx.db.query("purchase_receipts").collect()).toHaveLength(1)
    })
  })

  test("a transaction already used by one account cannot unlock another", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified())
    expect(await t.mutation(internal.billing.entitlements.applyVerified, verified({ userId: OTHER.subject })))
      .toEqual({ applied: false, reason: "already applied" })
    const theirs = await t.withIdentity(OTHER).query(api.billing.entitlements.mine, {})
    expect(theirs.subscription_status).toBe("none")
  })

  test("a renewal extends the one row rather than adding another", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt: Date.now() - DAY }))
    const later = Date.now() + 365 * DAY
    await t.mutation(internal.billing.entitlements.applyVerified, verified({
      verifiedTransactionId: "tx_2", productId: "os.personal.sub.yearly", expiresAt: later,
    }))

    expect(await t.withIdentity(ME).query(api.billing.entitlements.mine, {})).toEqual({
      subscription_status: "active", product_id: "os.personal.sub.yearly", expires_at: later,
    })
    await t.run(async (ctx) => {
      expect(await ctx.db.query("entitlements").collect()).toHaveLength(1)
      expect(await ctx.db.query("purchase_receipts").collect()).toHaveLength(2)
    })
  })
})

describe("the archive check", () => {
  test("is open while the subscription runs and shut once it ends", async () => {
    const t = convexTest(schema, modules)
    const expiresAt = Date.now() + DAY
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt }))
    const me = t.withIdentity(ME)
    expect(await me.query(api.billing.entitlements.subscribed, { now: expiresAt - 1 })).toBe(true)
    expect(await me.query(api.billing.entitlements.subscribed, { now: expiresAt + 1 })).toBe(false)
  })

  test("a subscription with no end date stays open", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, {
      userId: ME.subject, verifiedTransactionId: "tx_life", productId: "os.personal.sub.yearly",
    })
    expect(await t.withIdentity(ME).query(api.billing.entitlements.subscribed, { now: Date.now() }))
      .toBe(true)
  })
})

describe("the expiry sweep", () => {
  test("marks lapsed subscriptions expired and leaves running and open-ended ones alone", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt: Date.now() - 1 }))
    await t.mutation(internal.billing.entitlements.applyVerified, verified({
      userId: OTHER.subject, verifiedTransactionId: "tx_running", expiresAt: Date.now() + DAY,
    }))
    await t.mutation(internal.billing.entitlements.applyVerified, {
      userId: "user_forever", verifiedTransactionId: "tx_forever", productId: "os.personal.sub.yearly",
    })

    expect(await t.mutation(internal.billing.entitlements.expireLapsed, {})).toEqual({ expired: 1 })

    const statuses = await t.run(async (ctx) =>
      Object.fromEntries(
        (await ctx.db.query("entitlements").collect()).map((r) => [r.userId, r.subscription_status]),
      ),
    )
    expect(statuses).toEqual({ [ME.subject]: "expired", [OTHER.subject]: "active", user_forever: "active" })
  })

  test("once swept, an old clock from the phone does not reopen the archive", async () => {
    const t = convexTest(schema, modules)
    const expiresAt = Date.now() - 1
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt }))
    const me = t.withIdentity(ME)
    // Before the sweep the query can only go on the time it is given.
    expect(await me.query(api.billing.entitlements.subscribed, { now: expiresAt - DAY })).toBe(true)

    await t.mutation(internal.billing.entitlements.expireLapsed, {})
    expect(await me.query(api.billing.entitlements.subscribed, { now: expiresAt - DAY })).toBe(false)
  })

  test("a renewal after the sweep makes the subscription active again", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.billing.entitlements.applyVerified, verified({ expiresAt: Date.now() - 1 }))
    await t.mutation(internal.billing.entitlements.expireLapsed, {})
    await t.mutation(internal.billing.entitlements.applyVerified, verified({
      verifiedTransactionId: "tx_2", expiresAt: Date.now() + DAY,
    }))
    const mine = await t.withIdentity(ME).query(api.billing.entitlements.mine, {})
    expect(mine.subscription_status).toBe("active")
  })
})
