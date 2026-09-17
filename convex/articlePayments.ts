"use node"

import { v } from "convex/values"
import { Environment, SignedDataVerifier } from "@apple/app-store-server-library"
import { action } from "./_generated/server"
import { internal } from "./_generated/api"

/**
 * Turns an App Store purchase into time on Home, if Apple really signed it.
 *
 * The app sends the transaction's JWS. Its signature chains to Apple's root
 * certificates, so it can be checked here with nothing but those public roots.
 * A forged or altered transaction fails and never reaches applyPlacement.
 *
 * This replaces the pattern the older credit purchases used, a web route that
 * signed an HMAC grant for a public mutation. The web server is gone, and an
 * internal mutation needs no grant: no client can call it at all.
 *
 * Environment variables on the Convex deployment:
 *
 *   APPLE_ROOT_CERTS       Apple's root CA certificates, base64 DER, joined
 *                          with "|". Without them every purchase is refused.
 *   APPLE_IAP_ENVIRONMENT  "production" or "sandbox" (the default). "xcode"
 *                          accepts purchases made against a local StoreKit
 *                          configuration file, and those are NOT signed by
 *                          Apple — the library skips verification for them —
 *                          so it must only ever be set on a development
 *                          deployment, never on production.
 */

export const ARTICLE_PRODUCT_ID = "os.personal.article.30days"
const BUNDLE_ID = "ADEVSTUDIO.PersonalOSHealth"

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

export const confirmPlacement = action({
  args: { signedTransaction: v.string() },
  handler: async (ctx, args): Promise<{ applied: boolean; live_until: number }> => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const env = environment()
    const roots = appleRoots()
    if (env !== Environment.XCODE && roots.length === 0) {
      // Refusing is the only safe answer: granting unverified would make
      // placement free to anyone who can send a request.
      throw new Error("Purchase verification is not configured yet")
    }

    const verifier = new SignedDataVerifier(roots, true, env, BUNDLE_ID)
    let tx
    try {
      tx = await verifier.verifyAndDecodeTransaction(args.signedTransaction)
    } catch (error) {
      throw new Error("That purchase could not be verified with Apple")
    }

    if (tx.productId !== ARTICLE_PRODUCT_ID) throw new Error("That purchase is not for article placement")
    if (!tx.transactionId || !tx.appAccountToken) throw new Error("That purchase is missing its article")

    return await ctx.runMutation(internal.articles.applyPlacement, {
      authorToken: identity.tokenIdentifier,
      paymentToken: tx.appAccountToken.toLowerCase(),
      transactionId: tx.transactionId,
      productId: tx.productId,
    })
  },
})
