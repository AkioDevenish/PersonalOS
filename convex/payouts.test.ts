/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import schema from "./schema"
import { feeOn, feePercent } from "./fees"

const modules = import.meta.glob("./**/*.ts")

const PAYER = { subject: "user_payer", tokenIdentifier: "clerk|user_payer" }
const DOCTOR = { subject: "user_doctor", tokenIdentifier: "clerk|user_doctor" }

beforeEach(() => vi.stubEnv("PLATFORM_FEE_PERCENT", ""))
afterEach(() => vi.unstubAllEnvs())

describe("the platform's share", () => {
  test("is fifteen percent unless told otherwise", () => {
    expect(feePercent()).toBe(15)
    expect(feeOn(4000)).toBe(600)
    expect(feeOn(0)).toBe(0)
  })

  test("is configurable", () => {
    vi.stubEnv("PLATFORM_FEE_PERCENT", "20")
    expect(feeOn(4000)).toBe(800)
  })

  test("rounds to whole minor units, never a fraction of a cent", () => {
    vi.stubEnv("PLATFORM_FEE_PERCENT", "15")
    expect(feeOn(333)).toBe(50)
    expect(Number.isInteger(feeOn(777))).toBe(true)
  })

  test("a nonsense or dangerous percentage falls back to fifteen", () => {
    for (const bad of ["", "abc", "-5", "120"]) {
      vi.stubEnv("PLATFORM_FEE_PERCENT", bad)
      expect(feePercent()).toBe(15)
    }
  })
})

describe("what a payment records", () => {
  async function bookedSession() {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => {
      await ctx.db.insert("nutritionists", {
        userId: DOCTOR.subject, name: "Dr Doctor", country: "TT", credentials: "RD",
        bio: "", price_credits: 0, price_minor: 4000, currency: "TTD",
        active: true, status: "approved", updated_at: 0,
      })
    })
    const opened = await t.withIdentity(PAYER).mutation(api.health.consult.openSession, {
      specialistId: DOCTOR.subject, kind: "text",
    })
    return { t, id: opened.id }
  }

  test("the session names who is to be paid", async () => {
    const { t, id } = await bookedSession()
    const bill = await t.withIdentity(PAYER).query(api.health.consult.billing, { id })
    expect(bill.practitionerId).toBe(DOCTOR.subject)
    expect(bill.price_minor).toBe(4000)
  })

  test("a split payment records the fee and owes nothing", async () => {
    const { t, id } = await bookedSession()
    await t.withIdentity(PAYER).mutation(api.health.consult.attachPayment, {
      id, ref: "stripe:cs_1", feeMinor: feeOn(4000), owed: false,
    })
    await t.run(async (ctx) => {
      const row = await ctx.db.get(id)
      expect(row!.platform_fee_minor).toBe(600)
      expect(row!.payout_owed).toBe(false)
    })
  })

  test("an unsplit payment is marked as owed to the practitioner", async () => {
    const { t, id } = await bookedSession()
    await t.withIdentity(PAYER).mutation(api.health.consult.attachPayment, {
      id, ref: "wam:pi_1", feeMinor: feeOn(4000), owed: true,
    })
    await t.run(async (ctx) => {
      expect((await ctx.db.get(id))!.payout_owed).toBe(true)
    })
  })

  test("payout status is off until Stripe says otherwise", async () => {
    const { t } = await bookedSession()
    const before = await t.withIdentity(DOCTOR).query(api.payoutsData.mine, {})
    expect(before).toEqual({ started: false, ready: false, feePercent: 15 })

    await t.mutation(internal.payoutsData.remember, {
      userId: DOCTOR.subject, stripeAccount: "acct_1",
    })
    const started = await t.withIdentity(DOCTOR).query(api.payoutsData.mine, {})
    expect(started).toMatchObject({ started: true, ready: false })

    await t.mutation(internal.payoutsData.remember, {
      userId: DOCTOR.subject, payoutsEnabled: true,
    })
    expect(await t.withIdentity(DOCTOR).query(api.payoutsData.mine, {})).toMatchObject({ ready: true })
  })
})
