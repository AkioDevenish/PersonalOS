import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { Environment, SignedDataVerifier } from "@apple/app-store-server-library"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { productById, signGrant } from "@/lib/billing/products"

export const dynamic = "force-dynamic"

/**
 * Turns a StoreKit transaction into an entitlement, if Apple really signed it.
 *
 * The app sends the JWS representation of its transaction. That string is
 * signed by Apple with a certificate chain rooted in Apple's own CA, so this
 * can be checked here with nothing but the public roots — no App Store Connect
 * key, no network call to Apple. A forged or altered receipt fails the
 * signature and never reaches the grant.
 *
 * Skipping this and trusting the client is the single most common way IAP is
 * got wrong: `purchased == true` from a device is an assertion by an attacker,
 * not a fact.
 */

const BUNDLE_ID = "ADEVSTUDIO.PersonalOSHealth"

/**
 * Apple's root CAs, PEM-encoded, supplied through the environment rather than
 * committed. They are public certificates, but pinning them in a file makes
 * rotation a code change; an env var makes it a redeploy.
 */
function appleRoots(): Buffer[] {
  const raw = process.env.APPLE_ROOT_CERTS
  if (!raw) return []
  return raw
    .split("|")
    .map((b64) => b64.trim())
    .filter(Boolean)
    .map((b64) => Buffer.from(b64, "base64"))
}

export async function POST(request: Request) {
  const { userId, getToken } = await auth()
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
  const token = bearer || (await getToken({ template: "convex" }))
  if (!token) {
    return NextResponse.json({ error: "No Convex credential on this request" }, { status: 401 })
  }

  const body = (await request.json().catch(() => null)) as { signedTransaction?: string } | null
  const signed = body?.signedTransaction
  if (typeof signed !== "string" || !signed) {
    return NextResponse.json({ error: '"signedTransaction" is required' }, { status: 400 })
  }

  const roots = appleRoots()
  if (roots.length === 0) {
    // Refusing is the only safe answer. Granting without verification would
    // make every paid feature free to anyone who can send a POST.
    return NextResponse.json(
      { error: "Receipt verification isn't configured on this server (APPLE_ROOT_CERTS)." },
      { status: 503 },
    )
  }

  try {
    // Sandbox and production sign with different chains; StoreKit testing in
    // Xcode and TestFlight both land in sandbox.
    const environment =
      process.env.APPLE_IAP_ENVIRONMENT === "production"
        ? Environment.PRODUCTION
        : Environment.SANDBOX

    const verifier = new SignedDataVerifier(
      roots,
      true, // enable online checks for revoked certificates
      environment,
      BUNDLE_ID,
    )

    const tx = await verifier.verifyAndDecodeTransaction(signed)

    const productId = tx.productId
    const product = productId ? productById(productId) : undefined
    if (!product) {
      return NextResponse.json(
        { error: `Unrecognised product "${productId}"` },
        { status: 400 },
      )
    }
    const transactionId = tx.transactionId
    if (!transactionId) {
      return NextResponse.json({ error: "Transaction had no id" }, { status: 400 })
    }

    const expiresAt = product.kind === "subscription" ? tx.expiresDate : undefined
    const credits = product.kind === "credits" ? product.credits : undefined

    const convex = getConvexClient(token)
    const result = await convex.mutation(api.billing.entitlements.applyPurchase, {
      verifiedTransactionId: transactionId,
      kind: product.kind,
      productId: product.id,
      expiresAt,
      originalTransactionId: tx.originalTransactionId,
      creditsGranted: credits,
      grantSignature: signGrant({
        userId,
        transactionId,
        kind: product.kind,
        productId: product.id,
        expiresAt,
        credits,
      }),
    })

    return NextResponse.json({ ok: true, ...result })
  } catch (error) {
    // A signature failure is not a server error — it means the receipt is not
    // one Apple issued for this app.
    const message = error instanceof Error ? error.message : "Verification failed"
    console.error("[billing/verify] rejected:", message)
    return NextResponse.json({ error: `Couldn't verify that purchase: ${message}` }, { status: 400 })
  }
}
