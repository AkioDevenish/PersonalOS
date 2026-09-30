"use node"

import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { action } from "../_generated/server"
import { internal } from "../_generated/api"
import { verifyTransaction } from "../lib/appStore"

/** Turning an App Store purchase into an entitlement, if Apple really signed it. */

/** What can be bought, and never the client's to say which. */
const SUBSCRIPTIONS = new Set(["os.personal.sub.monthly", "os.personal.sub.yearly"])

export const verify = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, args): Promise<{ applied: boolean }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const tx = await verifyTransaction(args.signedTransaction)

    if (!tx.productId || !SUBSCRIPTIONS.has(tx.productId)) {
      throw new Error(`Unrecognised product "${tx.productId}"`)
    }
    if (!tx.transactionId) throw new Error("That purchase has no transaction id")

    const result = await ctx.runMutation(internal.billing.entitlements.applyVerified, {
      userId: userIdOf(identity),
      verifiedTransactionId: tx.transactionId,
      productId: tx.productId,
      expiresAt: tx.expiresDate,
      originalTransactionId: tx.originalTransactionId,
    })
    return { applied: result.applied }
  },
})
