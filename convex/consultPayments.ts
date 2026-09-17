"use node"

import { v } from "convex/values"
import crypto from "crypto"
import { action } from "./_generated/server"
import { api, internal } from "./_generated/api"

/**
 * Taking payment for a consultation, from Convex rather than a web server.
 *
 * Apple allows a processor other than in-app purchase here: guideline 3.1.3(d)
 * covers real-time person-to-person services and names medical consultations.
 * Article placement is different and uses in-app purchase; see
 * articlePayments.ts.
 *
 * A port of what a Next route used to do, moved because a phone app should not
 * need a web server of ours to be awake. The secrets stay server side either
 * way; they are Convex environment variables now:
 *
 *   STRIPE_SECRET_KEY
 *   WAM_API_KEY, WAM_BUSINESS_ID, WAM_ENVIRONMENT
 */

type Provider = "wam" | "stripe"

/** Currencies Wam settles in, and therefore the ones it should carry. */
const CARIBBEAN = new Set([
  "TTD", "JMD", "BBD", "XCD", "GYD", "BSD", "BZD", "SRD", "KYD", "AWG", "ANG",
])

function wamConfigured() {
  return Boolean(process.env.WAM_API_KEY && process.env.WAM_BUSINESS_ID)
}

function stripeConfigured() {
  return Boolean(process.env.STRIPE_SECRET_KEY)
}

function providerFor(currency: string): Provider | null {
  const code = currency.toUpperCase()
  if (CARIBBEAN.has(code) && wamConfigured()) return "wam"
  if (stripeConfigured()) return "stripe"
  // Wam also handles USD, EUR and GBP, so it stands in where Stripe is absent.
  if (wamConfigured()) return "wam"
  return null
}

/** Where a checkout sends somebody when it is done. Served by convex/http.ts. */
function returnUrl(): string {
  const site = (process.env.CONVEX_CLOUD_URL ?? "").replace(".convex.cloud", ".convex.site")
  return `${site}/pay/done`
}

function wamBase() {
  return process.env.WAM_ENVIRONMENT === "production"
    ? "https://billing.wam.money"
    : "https://staging.billing.wam.money"
}

/**
 * Wam signs the body rather than just the key: HMAC-SHA256 over
 * `{timestamp}.{json}`, keyed with the API key, lowercase hex. Signing the
 * exact string that is sent, not a re-serialised copy of it, is the part that
 * is easy to get wrong.
 */
function wamHeaders(body: string) {
  const timestamp = Math.floor(Date.now() / 1000).toString()
  const signature = crypto
    .createHmac("sha256", process.env.WAM_API_KEY!)
    .update(`${timestamp}.${body}`)
    .digest("hex")
  return {
    "Content-Type": "application/json",
    "X-WAM-Api-Key": process.env.WAM_API_KEY!,
    "X-WAM-Timestamp": timestamp,
    "X-WAM-Signature": signature,
  }
}

type Raised = { url: string; ref: string; provider: Provider }

async function wamCheckout(args: {
  amountMinor: number; currency: string; reference: string; description: string
}): Promise<Raised> {
  const body = JSON.stringify({
    amountCents: args.amountMinor,
    currency: args.currency.toUpperCase(),
    orderReference: args.reference,
    description: args.description,
    returnUrl: returnUrl(),
    // The session id, so a retry after a dropped connection cannot raise a
    // second charge for the same conversation.
    idempotencyKey: args.reference,
  })
  const response = await fetch(`${wamBase()}/api/public/payment-intents`, {
    method: "POST", headers: wamHeaders(body), body,
  })
  const json: any = await response.json().catch(() => null)
  if (!response.ok || !json?.checkoutUrl) {
    throw new Error(json?.message ?? `Wam refused the payment (${response.status})`)
  }
  return { url: json.checkoutUrl, ref: json.paymentId, provider: "wam" }
}

async function wamSettled(paymentId: string): Promise<boolean> {
  const response = await fetch(
    `${wamBase()}/api/public/payment-intents/${encodeURIComponent(paymentId)}`,
    { headers: wamHeaders("") },
  )
  if (!response.ok) return false
  const json: any = await response.json().catch(() => null)
  const status = String(json?.status ?? "").toLowerCase()
  return status === "paid" || status === "succeeded" || status === "completed"
}

/**
 * Stripe over its REST API rather than the SDK, which keeps a large
 * dependency out of the tree for two requests that are a form post each.
 */
async function stripeCheckout(args: {
  amountMinor: number; currency: string; reference: string; description: string
}): Promise<Raised> {
  const form = new URLSearchParams({
    mode: "payment",
    success_url: `${returnUrl()}?result=OK`,
    cancel_url: `${returnUrl()}?result=CANCELLED`,
    client_reference_id: args.reference,
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": args.currency.toLowerCase(),
    "line_items[0][price_data][unit_amount]": String(args.amountMinor),
    "line_items[0][price_data][product_data][name]": args.description,
  })
  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      // Same reasoning as Wam's key: one conversation, one charge.
      "Idempotency-Key": args.reference,
    },
    body: form,
  })
  const json: any = await response.json().catch(() => null)
  if (!response.ok || !json?.url) {
    throw new Error(json?.error?.message ?? `Stripe refused the payment (${response.status})`)
  }
  return { url: json.url, ref: json.id, provider: "stripe" }
}

async function stripeSettled(sessionId: string): Promise<boolean> {
  const response = await fetch(
    `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
    { headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}` } },
  )
  if (!response.ok) return false
  const json: any = await response.json().catch(() => null)
  return json?.payment_status === "paid"
}

/** Raises a checkout for a consultation and hands back the page to open. */
export const checkout = action({
  args: { id: v.id("consults") },
  handler: async (ctx, args): Promise<{ url: string | null; paid: boolean; error?: string }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const bill = await ctx.runQuery(api.health.consult.billing, { id: args.id })
    if (bill.payment_status === "paid" || bill.price_minor <= 0) return { url: null, paid: true }

    const provider = providerFor(bill.currency)
    if (!provider) {
      return { url: null, paid: false, error: "No payment processor is connected yet." }
    }

    const raised = provider === "wam"
      ? await wamCheckout({
          amountMinor: bill.price_minor, currency: bill.currency,
          reference: bill.id, description: bill.topic || "Consultation",
        })
      : await stripeCheckout({
          amountMinor: bill.price_minor, currency: bill.currency,
          reference: bill.id, description: bill.topic || "Consultation",
        })

    // Recorded before the payer leaves, so a payment that completes can be
    // traced back even if they close the app on the checkout page.
    await ctx.runMutation(api.health.consult.attachPayment, {
      id: args.id,
      ref: `${raised.provider}:${raised.ref}`,
    })
    return { url: raised.url, paid: false }
  },
})

/**
 * Asks the processor what happened, and only then marks the session paid.
 *
 * Coming back from a checkout page proves nothing: it is a URL the payer could
 * type themselves, and both processors say so in their own documentation. This
 * is the only path to paid, because the mutation behind it is internal.
 */
export const settled = action({
  args: { id: v.id("consults") },
  handler: async (ctx, args): Promise<{ paid: boolean }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const bill = await ctx.runQuery(api.health.consult.billing, { id: args.id })
    if (bill.payment_status === "paid" || bill.price_minor <= 0) return { paid: true }
    if (!bill.payment_ref) return { paid: false }

    // "wam:pi_123" — the provider travels with its own reference so a stored
    // payment can still be checked after the routing rules change.
    const [provider, ...rest] = bill.payment_ref.split(":")
    const ref = rest.join(":")
    if (provider !== "wam" && provider !== "stripe") return { paid: false }

    const paid = provider === "wam" ? await wamSettled(ref) : await stripeSettled(ref)
    if (paid) await ctx.runMutation(internal.health.consult.markPaidVerified, { id: args.id })
    return { paid }
  },
})
