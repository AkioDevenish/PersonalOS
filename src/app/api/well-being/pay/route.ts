import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"
import { createCheckout, isSettled, available, providerFor } from "@/lib/payments"

export const dynamic = "force-dynamic"

/**
 * Paying for one consultation.
 *
 * POST raises a checkout and hands back a URL for the phone to open. GET asks
 * the processor what actually happened and, only then, marks the session paid.
 *
 * The redirect back from a checkout page is never treated as proof. It is a
 * URL the payer could type themselves, and both processors say so in their own
 * documentation.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const body = await request.json().catch(() => null)
  const id = typeof body?.id === "string" ? body.id : ""
  if (!id) return NextResponse.json({ error: '"id" is required' }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const bill = await convex.query(api.health.consult.billing, { id: id as never })

    if (bill.payment_status === "paid") return NextResponse.json({ paid: true })
    if (bill.price_minor <= 0) return NextResponse.json({ paid: true })

    if (!providerFor(bill.currency)) {
      return NextResponse.json(
        {
          error: "No payment processor is connected yet.",
          configured: available(),
        },
        { status: 503 }
      )
    }

    const origin = new URL(request.url).origin
    const checkout = await createCheckout({
      amountMinor: bill.price_minor,
      currency: bill.currency,
      reference: bill.id,
      description: bill.topic || "Consultation",
      returnUrl: `${origin}/pay/done`,
    })

    // Recorded before the payer leaves, so a payment that completes can be
    // traced back even if they close the app on the checkout page.
    await convex.mutation(api.health.consult.attachPayment, {
      id: id as never,
      ref: `${checkout.provider}:${checkout.ref}`,
    })

    return NextResponse.json({ url: checkout.url, provider: checkout.provider })
  } catch (error) {
    console.error("[pay] checkout failed:", error)
    const message = error instanceof Error ? error.message : "Could not start the payment"
    return NextResponse.json({ error: message }, { status: 400 })
  }
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const id = new URL(request.url).searchParams.get("id")
  if (!id) return NextResponse.json({ error: '"id" is required' }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const bill = await convex.query(api.health.consult.billing, { id: id as never })

    if (bill.payment_status === "paid" || bill.price_minor <= 0) {
      return NextResponse.json({ paid: true })
    }
    if (!bill.payment_ref) return NextResponse.json({ paid: false })

    // "wam:pi_123" — the provider travels with its own reference so a stored
    // payment can still be checked after the routing rules change.
    const [provider, ...rest] = bill.payment_ref.split(":")
    const ref = rest.join(":")
    if (provider !== "wam" && provider !== "stripe") {
      return NextResponse.json({ paid: false })
    }

    const settled = await isSettled(provider, ref)
    if (settled) await convex.mutation(api.health.consult.markPaid, { id: id as never })
    return NextResponse.json({ paid: settled })
  } catch (error) {
    console.error("[pay] status check failed:", error)
    const message = error instanceof Error ? error.message : "Could not check the payment"
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
