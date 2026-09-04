import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"

export const dynamic = "force-dynamic"

/**
 * The money ledger's way in from the phone.
 *
 * Thin on purpose, like the rest: Convex owns what a valid entry is and who
 * may read whose rows. This route carries the call and nothing else.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

/** A window is required rather than defaulted, so no caller silently reads all history. */
function window(url: URL) {
  const from = Number(url.searchParams.get("from"))
  const to = Number(url.searchParams.get("to"))
  if (!Number.isFinite(from) || !Number.isFinite(to)) return null
  if (to < from) return null
  return { from, to }
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const range = window(new URL(request.url))
  if (!range) {
    return NextResponse.json({ error: '"from" and "to" are required' }, { status: 400 })
  }

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    return NextResponse.json(await convex.query(api.finance.ledger, range))
  } catch (error) {
    console.error("[finance] read failed:", error)
    const message = error instanceof Error ? error.message : "Failed to read the ledger"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const body = await request.json().catch(() => null)
  if (!body) return NextResponse.json({ error: "Expected a JSON body" }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    return NextResponse.json(
      await convex.mutation(api.finance.add, {
        date: Number(body.date),
        minor: Number(body.minor),
        currency: String(body.currency ?? ""),
        category: String(body.category ?? ""),
        note: typeof body.note === "string" ? body.note : undefined,
      })
    )
  } catch (error) {
    console.error("[finance] write failed:", error)
    const message = error instanceof Error ? error.message : "Failed to save"
    // A rejected entry is the caller's mistake, not the server's; 400 lets the
    // phone show the reason instead of "something went wrong".
    return NextResponse.json({ error: message }, { status: 400 })
  }
}

export async function DELETE(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const id = new URL(request.url).searchParams.get("id")
  if (!id) return NextResponse.json({ error: '"id" is required' }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    return NextResponse.json(
      await convex.mutation(api.finance.remove, { id: id as never })
    )
  } catch (error) {
    console.error("[finance] delete failed:", error)
    const message = error instanceof Error ? error.message : "Failed to remove"
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
