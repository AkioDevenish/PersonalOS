import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query } from "../_generated/server"

/** What a user is entitled to, and what they have left. */

async function requireUser(ctx: any): Promise<string> {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) throw new Error("Not authenticated")
  return userIdOf(identity)
}

const EMPTY = {
  subscription_status: "none",
  product_id: undefined as string | undefined,
  expires_at: undefined as number | undefined,
}

async function rowFor(ctx: any, userId: string) {
  return await ctx.db
    .query("entitlements")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first()
}

/** What the app should show. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx)
    const row = await rowFor(ctx, userId)
    if (!row) return EMPTY

    // A subscription that lapsed while the app was closed is not active, and no background job is
    // going to be reliable enough to have noticed.
    const lapsed =
      row.subscription_status === "active" &&
      typeof row.expires_at === "number" &&
      row.expires_at < Date.now()

    return {
      subscription_status: lapsed ? "expired" : row.subscription_status,
      product_id: row.product_id,
      expires_at: row.expires_at,
    }
  },
})

/** Applies a subscription that billing/receipts.ts has verified against Apple. */
export const applyVerified = internalMutation({
  args: {
    userId: v.string(),
    verifiedTransactionId: v.string(),
    productId: v.string(),
    expiresAt: v.optional(v.number()),
    originalTransactionId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const seen = await ctx.db
      .query("purchase_receipts")
      .withIndex("by_transactionId", (q) => q.eq("transactionId", args.verifiedTransactionId))
      .first()
    if (seen) return { applied: false, reason: "already applied" }

    const row = await rowFor(ctx, args.userId)
    const now = Date.now()
    const doc = {
      userId: args.userId,
      subscription_status: "active",
      product_id: args.productId,
      expires_at: args.expiresAt,
      original_transaction_id: args.originalTransactionId,
      updated_at: now,
    }
    if (row) await ctx.db.patch(row._id, doc)
    else await ctx.db.insert("entitlements", doc)

    await ctx.db.insert("purchase_receipts", {
      userId: args.userId,
      transactionId: args.verifiedTransactionId,
      productId: args.productId,
      created_at: now,
    })
    return { applied: true }
  },
})

/** Whether somebody may read the archive. */
export const subscribed = query({
  args: { now: v.number() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) return false
    const row = await rowFor(ctx, userIdOf(identity))
    if (row?.subscription_status !== "active") return false
    return typeof row.expires_at !== "number" || row.expires_at > args.now
  },
})
