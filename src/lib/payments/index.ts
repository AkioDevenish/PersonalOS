import crypto from "crypto"

/**
 * Taking a payment, through whichever processor fits the money.
 *
 * Both processors work the same way — raise an intent, send the payer to a
 * page the processor hosts, then ask the processor what happened. Neither is
 * ever trusted on the redirect: that URL is one the payer could type
 * themselves, and both providers say in their own documentation not to fulfil
 * on it alone. So the only thing that marks a session paid is an answer from
 * the processor's own status endpoint.
 *
 * Wam is a Caribbean wallet regulated in Trinidad and reaches thirty-odd
 * territories where Stripe does not operate at all. Stripe covers most
 * everywhere else. Which one a payment uses is decided by its currency, not by
 * asking the payer to know which of them their money lives in.
 */

export type Checkout = { url: string; ref: string; provider: Provider }
export type Provider = "wam" | "stripe"

/** Currencies Wam settles in, and therefore the ones it should carry. */
const CARIBBEAN = new Set([
  "TTD", "JMD", "BBD", "XCD", "GYD", "BSD", "BZD", "SRD", "KYD", "AWG", "ANG",
])

export function providerFor(currency: string): Provider | null {
  const code = currency.toUpperCase()
  if (CARIBBEAN.has(code) && wamConfigured()) return "wam"
  if (stripeConfigured()) return "stripe"
  // Wam also handles USD, EUR and GBP, so it stands in where Stripe is absent.
  if (wamConfigured()) return "wam"
  return null
}

export function wamConfigured() {
  return Boolean(process.env.WAM_API_KEY && process.env.WAM_BUSINESS_ID)
}

export function stripeConfigured() {
  return Boolean(process.env.STRIPE_SECRET_KEY)
}

/** Which processors are usable right now, for the screen that explains itself. */
export function available(): Provider[] {
  const out: Provider[] = []
  if (wamConfigured()) out.push("wam")
  if (stripeConfigured()) out.push("stripe")
  return out
}

// MARK: Wam

function wamBase() {
  return process.env.WAM_ENVIRONMENT === "production"
    ? "https://billing.wam.money"
    : "https://staging.billing.wam.money"
}

/**
 * Wam signs the body rather than just the key: HMAC-SHA256 over
 * `{timestamp}.{json}`, keyed with the API key, lowercase hex. Signing the
 * exact string that is sent — not a re-serialised copy of it — is the part
 * that is easy to get wrong.
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

async function wamCheckout(args: {
  amountMinor: number
  currency: string
  reference: string
  description: string
  returnUrl: string
}): Promise<Checkout> {
  const body = JSON.stringify({
    amountCents: args.amountMinor,
    currency: args.currency.toUpperCase(),
    orderReference: args.reference,
    description: args.description,
    returnUrl: args.returnUrl,
    // The session id, so a retry after a dropped connection cannot raise a
    // second charge for the same conversation.
    idempotencyKey: args.reference,
  })

  const response = await fetch(`${wamBase()}/api/public/payment-intents`, {
    method: "POST",
    headers: wamHeaders(body),
    body,
  })

  const json = await response.json().catch(() => null)
  if (!response.ok || !json?.checkoutUrl) {
    throw new Error(json?.message ?? `Wam refused the payment (${response.status})`)
  }
  return { url: json.checkoutUrl, ref: json.paymentId, provider: "wam" }
}

async function wamSettled(paymentId: string): Promise<boolean> {
  const response = await fetch(
    `${wamBase()}/api/public/payment-intents/${encodeURIComponent(paymentId)}`,
    { headers: wamHeaders("") }
  )
  if (!response.ok) return false
  const json = await response.json().catch(() => null)
  const status = String(json?.status ?? "").toLowerCase()
  return status === "paid" || status === "succeeded" || status === "completed"
}

// MARK: Stripe

/**
 * Called over the REST API rather than through the SDK, which keeps a large
 * dependency out of the tree for two requests that are a form post each.
 */
async function stripeCheckout(args: {
  amountMinor: number
  currency: string
  reference: string
  description: string
  returnUrl: string
}): Promise<Checkout> {
  const form = new URLSearchParams({
    mode: "payment",
    success_url: `${args.returnUrl}?result=OK`,
    cancel_url: `${args.returnUrl}?result=CANCELLED`,
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

  const json = await response.json().catch(() => null)
  if (!response.ok || !json?.url) {
    throw new Error(json?.error?.message ?? `Stripe refused the payment (${response.status})`)
  }
  return { url: json.url, ref: json.id, provider: "stripe" }
}

async function stripeSettled(sessionId: string): Promise<boolean> {
  const response = await fetch(
    `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
    { headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}` } }
  )
  if (!response.ok) return false
  const json = await response.json().catch(() => null)
  return json?.payment_status === "paid"
}

// MARK: The two things the route needs

export async function createCheckout(args: {
  amountMinor: number
  currency: string
  reference: string
  description: string
  returnUrl: string
}): Promise<Checkout> {
  const provider = providerFor(args.currency)
  if (!provider) throw new Error("No payment processor is configured")
  return provider === "wam" ? wamCheckout(args) : stripeCheckout(args)
}

export async function isSettled(provider: Provider, ref: string): Promise<boolean> {
  return provider === "wam" ? wamSettled(ref) : stripeSettled(ref)
}
