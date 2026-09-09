import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"
import { createRoom, mintToken, roomURL, videoProvider, jitsiURL } from "@/lib/video"

export const dynamic = "force-dynamic"

/**
 * Joining the call for one session.
 *
 * The room is made on first ask and reused after, so a dropped connection
 * rejoins the same call rather than opening a second one beside it. The token
 * is minted fresh every time, because a join is a moment and should not be
 * something a URL keeps letting you do.
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

  const provider = videoProvider()
  if (!provider) {
    return NextResponse.json({ error: "No video service is connected yet." }, { status: 503 })
  }

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const session = await convex.query(api.health.consult.billing, { id: id as never })

    if (session.kind !== "video") {
      return NextResponse.json({ error: "That session is not a call" }, { status: 400 })
    }
    // An unpaid call is not a call. The written conversation stays open, but
    // the practitioner's time is not given away by a URL.
    if (session.payment_status === "pending") {
      return NextResponse.json({ error: "This call has not been paid for" }, { status: 402 })
    }

    // The label over a video tile. The Caller carries no display name and a
    // call is not the place to go fetching one.
    const label = "You"

    // A Jitsi room needs no creating: it exists the moment somebody with a
    // valid token opens its name.
    if (provider === "jitsi") {
      return NextResponse.json({ url: jitsiURL(session.id, label) })
    }

    let room = session.room ?? ""
    if (!room || !room.startsWith("pos-")) {
      room = await createRoom(session.id)
      await convex.mutation(api.health.consult.attachRoom, { id: id as never, room })
    }

    const token = await mintToken(room, label)
    return NextResponse.json({ url: roomURL(room, token) })
  } catch (error) {
    console.error("[call] join failed:", error)
    const message = error instanceof Error ? error.message : "Could not open the call"
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
