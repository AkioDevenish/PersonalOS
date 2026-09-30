"use node"

import { v } from "convex/values"
import { internalAction } from "../_generated/server"
import { internal } from "../_generated/api"
import { verifyNotification } from "../lib/appStore"

/**
 * Apple's word on what happened to a purchase after it was made: renewals, expiries, refunds.
 * Posted to /appstore/notifications, which App Store Connect is pointed at.
 */
export const receive = internalAction({
  args: { signedPayload: v.string() },
  handler: async (ctx, args): Promise<{ ok: boolean }> => {
    let verified: Awaited<ReturnType<typeof verifyNotification>>
    try {
      verified = await verifyNotification(args.signedPayload)
    } catch {
      return { ok: false }
    }
    const { notification, transaction } = verified
    if (!notification.notificationType || !transaction?.transactionId) return { ok: true }

    await ctx.runMutation(internal.billing.entitlements.applyNotification, {
      type: notification.notificationType,
      transactionId: transaction.transactionId,
      originalTransactionId: transaction.originalTransactionId,
      productId: transaction.productId,
      expiresAt: transaction.expiresDate,
    })
    return { ok: true }
  },
})
