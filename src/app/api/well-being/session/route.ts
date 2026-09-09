import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"

export const dynamic = "force-dynamic"

/**
 * A conversation with one specialist: opening it, reading it, adding to it.
 *
 * GET is polled by the chat screen while it is on show. Convex is reactive but
 * the phone reaches it over HTTP through here, so there is no subscription to
 * hold — polling a few seconds apart is what makes a written conversation feel
 * live, and it stops the moment the screen closes.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const id = new URL(request.url).searchParams.get("id")
  if (!id) return NextResponse.json({ error: '"id" is required' }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    return NextResponse.json(await convex.query(api.health.consult.thread, { id: id as never }))
  } catch (error) {
    console.error("[session] read failed:", error)
    const message = error instanceof Error ? error.message : "Failed to read the conversation"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

/**
 * Two shapes, because they are two different acts.
 *
 * `{ specialistId, kind }` opens a conversation, and is the only place a fee is
 * taken. `{ id, body }` adds a message to one already open.
 */
export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const body = await request.json().catch(() => null)
  if (!body) return NextResponse.json({ error: "Expected a JSON body" }, { status: 400 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)

    if (typeof body.specialistId === "string") {
      const result = await convex.mutation(api.health.consult.openSession, {
        specialistId: body.specialistId,
        kind: body.kind === "video" ? "video" : "text",
        topic: typeof body.topic === "string" ? body.topic : undefined,
      })
      return NextResponse.json(result)
    }

    if (typeof body.id === "string" && typeof body.body === "string") {
      await convex.mutation(api.health.consult.send, {
        id: body.id as never,
        body: body.body,
      })
      return NextResponse.json({ sent: true })
    }

    return NextResponse.json({ error: "Expected a specialist or a message" }, { status: 400 })
  } catch (error) {
    console.error("[session] write failed:", error)
    const message = error instanceof Error ? error.message : "Failed"
    // A refused session is nearly always "not enough credits", which the
    // person can act on, so the reason travels rather than a generic failure.
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
