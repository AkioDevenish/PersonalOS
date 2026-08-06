import crypto from "crypto"

/**
 * What can be bought, defined once and shared by the verifier and the app.
 *
 * Credit counts live here rather than in the purchase Apple sends, because
 * the client tells us which product was bought and nothing more — how much
 * that product is worth has to be decided somewhere the client can't reach.
 */

export type ProductKind = "subscription" | "credits"

export type Product = {
  id: string
  kind: ProductKind
  label: string
  /** Consumables only: how many hosted model calls this buys. */
  credits?: number
}

export const PRODUCTS: Product[] = [
  {
    id: "os.personal.sub.monthly",
    kind: "subscription",
    label: "Personal OS, monthly",
  },
  {
    id: "os.personal.sub.yearly",
    kind: "subscription",
    label: "Personal OS, yearly",
  },
  { id: "os.personal.credits.50", kind: "credits", label: "50 readings", credits: 50 },
  { id: "os.personal.credits.200", kind: "credits", label: "200 readings", credits: 200 },
]

export function productById(id: string): Product | undefined {
  return PRODUCTS.find((p) => p.id === id)
}

/**
 * Signs a grant for Convex.
 *
 * Convex cannot tell the verification route apart from the phone — both arrive
 * as the same authenticated user — so the entitlement mutation refuses
 * anything without this. The user id is inside the signed payload, so a grant
 * captured from one account is worthless against another.
 */
export function signGrant(input: {
  userId: string
  transactionId: string
  kind: ProductKind
  productId: string
  expiresAt?: number
  credits?: number
}): string {
  const secret = process.env.BILLING_GRANT_SECRET
  if (!secret) throw new Error("Server is missing BILLING_GRANT_SECRET")
  const payload = [
    input.userId,
    input.transactionId,
    input.kind,
    input.productId,
    input.expiresAt ?? "",
    input.credits ?? "",
  ].join("|")
  return crypto.createHmac("sha256", secret).update(payload).digest("hex")
}
