"use node"

import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { Environment, SignedDataVerifier } from "@apple/app-store-server-library"
import { action } from "../_generated/server"
import { internal } from "../_generated/api"

/** Turning an App Store purchase into an entitlement, if Apple really signed it. */

const BUNDLE_ID = "com.adevstudio.forklore"

/** What can be bought, and never the client's to say which. */
const SUBSCRIPTIONS = new Set(["os.personal.sub.monthly", "os.personal.sub.yearly"])

function environment(): Environment {
  switch (process.env.APPLE_IAP_ENVIRONMENT) {
    case "production": return Environment.PRODUCTION
    case "xcode": return Environment.XCODE
    default: return Environment.SANDBOX
  }
}

function appleRoots(): Buffer[] {
  return (process.env.APPLE_ROOT_CERTS ?? "")
    .split("|")
    .map((b64) => b64.trim())
    .filter(Boolean)
    .map((b64) => Buffer.from(b64, "base64"))
}

export const verify = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, args): Promise<{ applied: boolean }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const env = environment()
    const roots = appleRoots()
    if (env !== Environment.XCODE && roots.length === 0) {
      throw new Error("Purchase verification is not configured yet")
    }

    const verifier = new SignedDataVerifier(roots, true, env, BUNDLE_ID)
    let tx
    try {
      tx = await verifier.verifyAndDecodeTransaction(args.signedTransaction)
    } catch {
      throw new Error("That purchase could not be verified with Apple")
    }

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
