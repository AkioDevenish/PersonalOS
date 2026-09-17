import { v } from "convex/values"
import { internalMutation, mutation, query } from "../_generated/server"

/**
 * What a user is entitled to, and what they have left.
 *
 * The asymmetry here is the point. Reads are public and scoped to the caller —
 * the app needs to know whether to show a paywall. Writes that *grant*
 * anything are not callable by the app at all: `applyPurchase` takes a
 * verification marker the Next layer only produces after checking Apple's
 * signature on the transaction. A client that could call it directly could
 * give itself a subscription for nothing.
 *
 * Spending is different from granting and is safe to expose: it only ever
 * decreases a balance, and it refuses to go below zero.
 */

async function requireUser(ctx: any): Promise<string> {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) throw new Error("Not authenticated")
  return identity.subject
}

const EMPTY = {
  subscription_status: "none",
  product_id: undefined as string | undefined,
  expires_at: undefined as number | undefined,
  credits: 0,
}

async function rowFor(ctx: any, userId: string) {
  return await ctx.db
    .query("entitlements")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first()
}

/** What the app should show. Expiry is evaluated on read, never on a timer. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx)
    const row = await rowFor(ctx, userId)
    if (!row) return EMPTY

    // A subscription that lapsed while the app was closed is not active, and
    // no background job is going to be reliable enough to have noticed.
    const lapsed =
      row.subscription_status === "active" &&
      typeof row.expires_at === "number" &&
      row.expires_at < Date.now()

    return {
      subscription_status: lapsed ? "expired" : row.subscription_status,
      product_id: row.product_id,
      expires_at: row.expires_at,
      credits: row.credits,
    }
  },
})

/**
 * Proves a grant came from the verification route rather than from a client.
 *
 * Convex has no way to tell who called a public mutation beyond the user's
 * identity, and the caller here is the user's own phone. Without this, the
 * arguments below are just numbers someone could type — `credits: 100000` and
 * a transaction id of "1" would be a free subscription. The Next layer checks
 * Apple's signature on the receipt and then signs the resulting grant with a
 * secret only the two servers share; this recomputes it.
 *
 * Same shape as the HMAC on the OAuth state parameter, for the same reason:
 * a value that crosses an untrusted boundary and has to come back unaltered.
 */
/**
 * Applies a purchase that billing/receipts.ts has verified against Apple.
 *
 * Internal, so verification is the only way in. It used to be public, with an
 * HMAC grant proving a web route had checked the receipt first: a signature
 * scheme that existed only because Convex could not tell that route apart from
 * the phone. Nothing outside Convex calls this now, so the grant is gone.
 *
 * `verifiedTransactionId` doubles as the idempotency key. Apple redelivers
 * transactions routinely — on reinstall, on restore, on every launch until
 * they are finished — and granting credits again each time would be free money.
 */
export const applyVerified = internalMutation({
  args: {
    userId: v.string(),
    verifiedTransactionId: v.string(),
    kind: v.string(), // "subscription" | "credits"
    productId: v.string(),
    expiresAt: v.optional(v.number()),
    originalTransactionId: v.optional(v.string()),
    creditsGranted: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const userId = args.userId
    const seen = await ctx.db
      .query("ai_credit_ledger")
      .withIndex("by_transaction", (q) => q.eq("transaction_id", args.verifiedTransactionId))
      .first()
    if (seen) {
      const row = await rowFor(ctx, userId)
      return { applied: false, credits: row?.credits ?? 0, reason: "already applied" }
    }

    const row = await rowFor(ctx, userId)
    const now = Date.now()

    if (args.kind === "subscription") {
      const doc = {
        userId,
        subscription_status: "active",
        product_id: args.productId,
        expires_at: args.expiresAt,
        original_transaction_id: args.originalTransactionId,
        credits: row?.credits ?? 0,
        updated_at: now,
      }
      if (row) await ctx.db.patch(row._id, doc)
      else await ctx.db.insert("entitlements", doc)

      // A zero delta claims the transaction id, so a redelivered renewal
      // cannot be applied twice.
      await ctx.db.insert("ai_credit_ledger", {
        userId,
        delta: 0,
        reason: `subscription ${args.productId}`,
        transaction_id: args.verifiedTransactionId,
        created_at: now,
      })
      return { applied: true, credits: row?.credits ?? 0 }
    }

    const granted = Math.max(0, Math.floor(args.creditsGranted ?? 0))
    const credits = (row?.credits ?? 0) + granted
    if (row) await ctx.db.patch(row._id, { credits, updated_at: now })
    else {
      await ctx.db.insert("entitlements", {
        userId,
        subscription_status: "none",
        credits,
        updated_at: now,
      })
    }
    await ctx.db.insert("ai_credit_ledger", {
      userId,
      delta: granted,
      reason: `purchase ${args.productId}`,
      transaction_id: args.verifiedTransactionId,
      created_at: now,
    })
    return { applied: true, credits }
  },
})

export const spend = mutation({
  args: { reason: v.string(), amount: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx)
    const row = await rowFor(ctx, userId)
    const amount = Math.max(1, Math.floor(args.amount ?? 1))

    const subscribed =
      row?.subscription_status === "active" &&
      (typeof row.expires_at !== "number" || row.expires_at > Date.now())
    if (subscribed) return { charged: false, credits: row?.credits ?? 0 }

    const balance = row?.credits ?? 0
    if (balance < amount) {
      throw new Error("Not enough credits")
    }

    await ctx.db.patch(row!._id, { credits: balance - amount, updated_at: Date.now() })
    await ctx.db.insert("ai_credit_ledger", {
      userId,
      delta: -amount,
      reason: args.reason,
      created_at: Date.now(),
    })
    return { charged: true, credits: balance - amount }
  },
})
