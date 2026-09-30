/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import type { Id } from "./_generated/dataModel"
import schema from "./schema"

const modules = import.meta.glob("./**/*.ts")

const PAYER = { subject: "user_payer", tokenIdentifier: "clerk|user_payer" }
const STRANGER = { subject: "user_stranger", tokenIdentifier: "clerk|user_stranger" }
const DOCTOR = "user_doctor"

type Call = { url: string; init?: RequestInit }

/** Stands in for Wam and Stripe, answering each request with the next reply in line. */
function processor(...replies: Array<{ status?: number; body: unknown }>) {
  const calls: Call[] = []
  vi.stubGlobal("fetch", vi.fn(async (url: string, init?: RequestInit) => {
    calls.push({ url: String(url), init })
    const reply = replies.shift() ?? { status: 500, body: {} }
    return new Response(JSON.stringify(reply.body), { status: reply.status ?? 200 })
  }))
  return calls
}

beforeEach(() => {
  vi.stubEnv("PLATFORM_FEE_PERCENT", "")
  vi.stubEnv("WAM_API_KEY", "")
  vi.stubEnv("WAM_BUSINESS_ID", "")
  vi.stubEnv("STRIPE_SECRET_KEY", "")
  vi.stubEnv("CONVEX_CLOUD_URL", "https://test-1.convex.cloud")
})
afterEach(() => {
  vi.unstubAllEnvs()
  vi.unstubAllGlobals()
})

function wam() {
  vi.stubEnv("WAM_API_KEY", "wam_key")
  vi.stubEnv("WAM_BUSINESS_ID", "biz_1")
}

function stripe() {
  vi.stubEnv("STRIPE_SECRET_KEY", "sk_test_1")
}

async function booked(price = { minor: 4000, currency: "TTD" }) {
  const t = convexTest(schema, modules)
  await t.run(async (ctx) => {
    await ctx.db.insert("nutritionists", {
      userId: DOCTOR, name: "Dr Doctor", country: "TT", credentials: "RD",
      bio: "", price_credits: 0, price_minor: price.minor, currency: price.currency,
      active: true, status: "approved", updated_at: 0,
    })
  })
  const opened = await t.withIdentity(PAYER).mutation(api.health.consult.openSession, {
    specialistId: DOCTOR, kind: "text",
  })
  return { t, id: opened.id as Id<"consults"> }
}

async function row(t: ReturnType<typeof convexTest>, id: Id<"consults">) {
  return await t.run(async (ctx) => await ctx.db.get(id))
}

describe("raising a checkout", () => {
  test("a free session needs no checkout at all", async () => {
    const calls = processor()
    stripe()
    const { t, id } = await booked({ minor: 0, currency: "TTD" })
    const result = await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    expect(result).toEqual({ url: null, paid: true })
    expect(calls).toHaveLength(0)
  })

  test("says so plainly when no processor is connected", async () => {
    const calls = processor()
    const { t, id } = await booked()
    const result = await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    expect(result).toEqual({ url: null, paid: false, error: "No payment processor is connected yet." })
    expect(calls).toHaveLength(0)
  })

  test("Caribbean currencies go to Wam, signed, with the session as the idempotency key", async () => {
    wam()
    stripe()
    const calls = processor({ body: { checkoutUrl: "https://wam.test/pay", paymentId: "pi_1" } })
    const { t, id } = await booked({ minor: 4000, currency: "TTD" })

    const result = await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    expect(result).toEqual({ url: "https://wam.test/pay", paid: false })

    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("https://staging.billing.wam.money/api/public/payment-intents")
    const headers = calls[0].init!.headers as Record<string, string>
    expect(headers["X-WAM-Signature"]).toMatch(/^[0-9a-f]{64}$/)
    const body = JSON.parse(String(calls[0].init!.body))
    expect(body).toMatchObject({
      amountCents: 4000, currency: "TTD", orderReference: id, idempotencyKey: id,
      returnUrl: "https://test-1.convex.site/pay/done",
    })

    const saved = await row(t, id)
    expect(saved!.payment_ref).toBe("wam:pi_1")
    expect(saved!.platform_fee_minor).toBe(600)
    // Wam never splits, so the practitioner's share is still to be sent.
    expect(saved!.payout_owed).toBe(true)
    expect(saved!.payment_status).toBe("pending")
  })

  test("other currencies go to Stripe when it is connected", async () => {
    wam()
    stripe()
    const calls = processor({ body: { url: "https://stripe.test/cs_1", id: "cs_1" } })
    const { t, id } = await booked({ minor: 2500, currency: "USD" })

    await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    expect(calls[0].url).toBe("https://api.stripe.com/v1/checkout/sessions")
    const form = new URLSearchParams(String(calls[0].init!.body))
    expect(form.get("line_items[0][price_data][currency]")).toBe("usd")
    expect(form.get("line_items[0][price_data][unit_amount]")).toBe("2500")
    expect(form.get("client_reference_id")).toBe(id)
    expect((calls[0].init!.headers as Record<string, string>)["Idempotency-Key"]).toBe(id)
    expect((await row(t, id))!.payment_ref).toBe("stripe:cs_1")
  })

  test("Stripe splits the payment when the practitioner can be paid directly", async () => {
    stripe()
    const calls = processor({ body: { url: "https://stripe.test/cs_2", id: "cs_2" } })
    const { t, id } = await booked({ minor: 4000, currency: "USD" })
    await t.mutation(internal.payoutsData.remember, {
      userId: DOCTOR, stripeAccount: "acct_doc", payoutsEnabled: true,
    })

    await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    const form = new URLSearchParams(String(calls[0].init!.body))
    expect(form.get("payment_intent_data[transfer_data][destination]")).toBe("acct_doc")
    expect(form.get("payment_intent_data[application_fee_amount]")).toBe("600")
    expect((await row(t, id))!.payout_owed).toBe(false)
  })

  test("does not split to a practitioner who has not finished onboarding", async () => {
    stripe()
    const calls = processor({ body: { url: "https://stripe.test/cs_3", id: "cs_3" } })
    const { t, id } = await booked({ minor: 4000, currency: "USD" })
    await t.mutation(internal.payoutsData.remember, { userId: DOCTOR, stripeAccount: "acct_doc" })

    await t.withIdentity(PAYER).action(api.consultPayments.checkout, { id })
    const form = new URLSearchParams(String(calls[0].init!.body))
    expect(form.has("payment_intent_data[transfer_data][destination]")).toBe(false)
    expect((await row(t, id))!.payout_owed).toBe(true)
  })

  test("a refusal from the processor surfaces and records nothing", async () => {
    stripe()
    processor({ status: 402, body: { error: { message: "Card declined" } } })
    const { t, id } = await booked({ minor: 4000, currency: "USD" })

    await expect(
      t.withIdentity(PAYER).action(api.consultPayments.checkout, { id }),
    ).rejects.toThrow("Card declined")
    expect((await row(t, id))!.payment_ref).toBeUndefined()
  })

  test("nobody can raise a checkout on someone else's session", async () => {
    stripe()
    const calls = processor()
    const { t, id } = await booked()
    await expect(
      t.withIdentity(STRANGER).action(api.consultPayments.checkout, { id }),
    ).rejects.toThrow("No such session")
    expect(calls).toHaveLength(0)
  })

  test("needs a signed-in user", async () => {
    const { t, id } = await booked()
    await expect(t.action(api.consultPayments.checkout, { id })).rejects.toThrow("Not authenticated")
  })
})

describe("the payment reference", () => {
  test("is not the client's to set", () => {
    // If attachPayment were public, a payer could point an unpaid session at any checkout that
    // was paid, and `settled` would believe it. tsc fails here if it ever becomes public again.
    // @ts-expect-error attachPayment must stay internal
    expect(api.health.consult.attachPayment).toBeDefined()
  })
})

describe("confirming a payment", () => {
  async function raised(provider: "wam" | "stripe") {
    wam()
    stripe()
    const currency = provider === "wam" ? "TTD" : "USD"
    processor(provider === "wam"
      ? { body: { checkoutUrl: "https://wam.test/pay", paymentId: "pi_9" } }
      : { body: { url: "https://stripe.test/cs_9", id: "cs_9" } })
    const booking = await booked({ minor: 4000, currency })
    await booking.t.withIdentity(PAYER).action(api.consultPayments.checkout, { id: booking.id })
    return booking
  }

  test("marks the session paid only once Stripe says it is", async () => {
    const { t, id } = await raised("stripe")

    let calls = processor({ body: { payment_status: "unpaid" } })
    expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: false })
    expect(calls[0].url).toBe("https://api.stripe.com/v1/checkout/sessions/cs_9")
    expect((await row(t, id))!.payment_status).toBe("pending")

    calls = processor({ body: { payment_status: "paid" } })
    expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: true })
    expect((await row(t, id))!.payment_status).toBe("paid")
  })

  test("accepts each of Wam's words for a finished payment", async () => {
    for (const status of ["paid", "SUCCEEDED", "completed"]) {
      const { t, id } = await raised("wam")
      const calls = processor({ body: { status } })
      expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: true })
      expect(calls[0].url).toBe("https://staging.billing.wam.money/api/public/payment-intents/pi_9")
    }
  })

  test("an error from the processor is not a payment", async () => {
    const { t, id } = await raised("wam")
    processor({ status: 503, body: { status: "paid" } })
    expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: false })
    expect((await row(t, id))!.payment_status).toBe("pending")
  })

  test("a session with no checkout yet is not paid, and nothing is asked", async () => {
    const calls = processor()
    stripe()
    const { t, id } = await booked({ minor: 4000, currency: "USD" })
    expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: false })
    expect(calls).toHaveLength(0)
  })

  test("a session already paid is not checked again", async () => {
    const { t, id } = await raised("stripe")
    await t.mutation(internal.health.consult.markPaidVerified, { id })
    const calls = processor()
    expect(await t.withIdentity(PAYER).action(api.consultPayments.settled, { id })).toEqual({ paid: true })
    expect(calls).toHaveLength(0)
  })

  test("nobody can settle someone else's session", async () => {
    const { t, id } = await raised("stripe")
    await expect(
      t.withIdentity(STRANGER).action(api.consultPayments.settled, { id }),
    ).rejects.toThrow("No such session")
  })
})

describe("an unpaid session", () => {
  const DOCTOR_ID = { subject: DOCTOR, tokenIdentifier: `clerk|${DOCTOR}` }

  test("takes no messages from either side until it is paid", async () => {
    const { t, id } = await booked()
    for (const who of [PAYER, DOCTOR_ID]) {
      await expect(
        t.withIdentity(who).mutation(api.health.consult.send, { id, body: "Hello" }),
      ).rejects.toThrow("hasn't been paid for yet")
    }

    await t.mutation(internal.health.consult.markPaidVerified, { id })
    await t.withIdentity(PAYER).mutation(api.health.consult.send, { id, body: "Hello" })
    const messages = await t.run(async (ctx) =>
      await ctx.db.query("consult_messages").withIndex("by_consult", (q) => q.eq("consultId", id)).take(10))
    expect(messages).toHaveLength(1)
  })

  test("cannot be used to place a call", async () => {
    const { t, id } = await booked()
    await expect(
      t.withIdentity(PAYER).mutation(api.health.signal.post, { id, kind: "offer", payload: "sdp" }),
    ).rejects.toThrow("hasn't been paid for yet")
  })

  test("a free session is open straight away", async () => {
    const { t, id } = await booked({ minor: 0, currency: "TTD" })
    await t.withIdentity(PAYER).mutation(api.health.consult.send, { id, body: "Hello" })
  })
})
