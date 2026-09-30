import type { Doc } from "../_generated/dataModel"

/**
 * A priced consultation opens as "pending" and only the payment processor can make it "paid".
 * Until then neither side may talk on it, so the server, not just the app, is what holds the line.
 * Rows from before pricing have no status and were free.
 */
export function requireSettled(consult: Pick<Doc<"consults">, "payment_status">) {
  if (consult.payment_status === "pending") {
    throw new Error("This session hasn't been paid for yet")
  }
}
