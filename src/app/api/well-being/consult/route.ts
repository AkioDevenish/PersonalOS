import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"

export const dynamic = "force-dynamic"

/**
 * The phone's way into a conversation with a nutritionist.
 *
 * Thin: Convex owns who may read what, who counts as a professional, and when
 * a consultation stops being "waiting". This route carries messages.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const url = new URL(request.url)
  const id = url.searchParams.get("id")

  try {
    const convex = getConvexClient(bearer(request) || caller.token)

    if (id) {
      const thread = await convex.query(api.health.consult.thread, { id: id as never })
      return NextResponse.json(thread)
    }

    const [consults, staffed] = await Promise.all([
      convex.query(api.health.consult.mine, {}),
      convex.query(api.health.consult.staffed, {}),
    ])
    return NextResponse.json({ consults, ...staffed })
  } catch (error) {
    console.error("[well-being/consult] read failed:", error)
    const message = error instanceof Error ? error.message : "Failed to read consultations"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

/**
 * `{ question }` opens a consultation; `{ id, body }` adds to one.
 */
export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const body = await request.json().catch(() => null)

  try {
    const convex = getConvexClient(bearer(request) || caller.token)

    if (typeof body?.id === "string" && typeof body?.body === "string") {
      const result = await convex.mutation(api.health.consult.send, {
        id: body.id as never,
        body: body.body,
      })
      return NextResponse.json(result)
    }

    const question = typeof body?.question === "string" ? body.question : ""
    if (!question.trim()) {
      return NextResponse.json({ error: '"question" is required' }, { status: 400 })
    }

    const result = await convex.mutation(api.health.consult.start, {
      topic: typeof body?.topic === "string" ? body.topic : "Nutrition",
      question,
      shared: typeof body?.shared === "string" ? body.shared : undefined,
      country: typeof body?.country === "string" ? body.country : undefined,
    })
    return NextResponse.json(result)
  } catch (error) {
    console.error("[well-being/consult] write failed:", error)
    const message = error instanceof Error ? error.message : "Failed to send"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
