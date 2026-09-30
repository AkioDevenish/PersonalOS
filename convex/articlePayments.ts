"use node"

import { userIdOf } from "./lib/me"
import { v } from "convex/values"
import { action } from "./_generated/server"
import { internal } from "./_generated/api"
import { verifyTransaction } from "./lib/appStore"

/** Turns an App Store purchase into time on Home, if Apple really signed it. */

export const ARTICLE_PRODUCT_ID = "os.personal.article.30days"

export const confirmPlacement = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, args): Promise<{ applied: boolean; live_until: number }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const tx = await verifyTransaction(args.signedTransaction)

    if (tx.productId !== ARTICLE_PRODUCT_ID) throw new Error("That purchase is not for article placement")
    if (!tx.transactionId || !tx.appAccountToken) throw new Error("That purchase is missing its article")

    return await ctx.runMutation(internal.articles.applyPlacement, {
      authorToken: userIdOf(identity),
      paymentToken: tx.appAccountToken.toLowerCase(),
      transactionId: tx.transactionId,
      productId: tx.productId,
    })
  },
})
