"use node"

import { userIdOf } from "./lib/me"
import { v } from "convex/values"
import { action } from "./_generated/server"
import { internal } from "./_generated/api"
import { feePercent } from "./fees"

/**
 * Paying practitioners, and taking the platform's share on the way past.
 *
 * Stripe Connect. Each practitioner gets their own Stripe account, and a
 * client's payment is split at the moment it is made: the practitioner is paid
 * directly, and the platform fee is taken out in the same transaction.
 *
 * Before this, a consultation fee landed whole in our account with nothing to
 * send it onward. That is not income, it is a debt to whoever did the work.
 *
 *   PLATFORM_FEE_PERCENT   the platform's share, default 15 (see fees.ts)
 *   STRIPE_SECRET_KEY      the same key the checkout uses
 *
 * Bank details are typed on Stripe's own pages, never here. This app never
 * sees them, which is the point of using Connect rather than collecting them.
 */

const STRIPE = "https://api.stripe.com/v1"

async function stripe(path: string, form?: Record<string, string>): Promise<any> {
  const key = process.env.STRIPE_SECRET_KEY
  if (!key) throw new Error("Stripe is not connected yet")
  const response = await fetch(`${STRIPE}${path}`, {
    method: form ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${key}`,
      ...(form ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body: form ? new URLSearchParams(form) : undefined,
  })
  const json: any = await response.json().catch(() => null)
  if (!response.ok) throw new Error(json?.error?.message ?? `Stripe refused that (${response.status})`)
  return json
}

function site(): string {
  return (process.env.CONVEX_CLOUD_URL ?? "").replace(".convex.cloud", ".convex.site")
}

/**
 * Starts or resumes a practitioner's Stripe onboarding, and hands back the
 * page to send them to.
 *
 * The account is made once and remembered; the link is short-lived by Stripe's
 * design, so a fresh one is minted every time somebody asks.
 */
export const link = action({
  args: {},
  handler: async (ctx): Promise<{ url: string }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const profile = await ctx.runQuery(internal.payoutsData.profileFor, { userId: userIdOf(identity) })
    if (!profile) throw new Error("Apply to be listed first")
    if (profile.status !== "approved") throw new Error("Payouts open once your application is approved")

    let account = profile.stripe_account
    if (!account) {
      const created = await stripe("/accounts", {
        type: "express",
        "capabilities[transfers][requested]": "true",
        "business_profile[product_description]": "Health consultations on Personal OS",
        ...(profile.country ? { country: profile.country } : {}),
        ...(identity.email ? { email: identity.email } : {}),
      })
      account = created.id as string
      await ctx.runMutation(internal.payoutsData.remember, {
        userId: userIdOf(identity),
        stripeAccount: account,
      })
    }

    const link = await stripe("/account_links", {
      account,
      type: "account_onboarding",
      refresh_url: `${site()}/payouts/done`,
      return_url: `${site()}/payouts/done`,
    })
    return { url: link.url as string }
  },
})

/**
 * Asks Stripe whether this practitioner can actually be paid yet.
 *
 * Onboarding is not finished when somebody returns from it: Stripe may still
 * be verifying, and it is `payouts_enabled` that decides, not the redirect.
 */
export const refresh = action({
  args: {},
  handler: async (ctx): Promise<{ ready: boolean }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const profile = await ctx.runQuery(internal.payoutsData.profileFor, { userId: userIdOf(identity) })
    if (!profile?.stripe_account) return { ready: false }

    const account = await stripe(`/accounts/${profile.stripe_account}`)
    const ready = Boolean(account.payouts_enabled && account.charges_enabled)
    await ctx.runMutation(internal.payoutsData.remember, {
      userId: userIdOf(identity),
      payoutsEnabled: ready,
    })
    return { ready }
  },
})
