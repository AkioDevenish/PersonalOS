import { userIdOf } from "./lib/me"
import { v } from "convex/values"
import { internalMutation, internalQuery, query } from "./_generated/server"
import { feePercent } from "./fees"

/**
 * The database half of payouts. The Stripe half is in payouts.ts, which is a
 * Node action and so cannot touch the database itself.
 */

export const profileFor = internalQuery({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first()
  },
})

export const remember = internalMutation({
  args: {
    userId: v.string(),
    stripeAccount: v.optional(v.string()),
    payoutsEnabled: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first()
    if (!row) throw new Error("Apply to be listed first")
    await ctx.db.patch(row._id, {
      stripe_account: args.stripeAccount ?? row.stripe_account,
      payouts_enabled: args.payoutsEnabled ?? row.payouts_enabled,
      updated_at: Date.now(),
    })
    return null
  },
})

/** What the practitioner's own screen shows about being paid. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()
    return {
      started: Boolean(row?.stripe_account),
      ready: row?.payouts_enabled === true,
      /** What the platform keeps, as a percentage, for the screen to state. */
      feePercent: feePercent(),
    }
  },
})
