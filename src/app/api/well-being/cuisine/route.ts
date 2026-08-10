import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"

export const dynamic = "force-dynamic"

/**
 * The dishes a country actually eats, as told by the people who eat there.
 *
 * The meal engine was naming food that doesn't exist, because asking a model to
 * recall everyday dishes from a country it barely knows is the hard version of
 * the task. This is the easy version: hand it a list and let it choose. The
 * list is built by people, one vote each, and a dish enters the vocabulary when
 * enough of them have named it.
 *
 * Thin on purpose — Convex holds the rules about who may vote and what counts
 * as canon. This route is the phone's way in.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const country = new URL(request.url).searchParams.get("country")?.trim()
  if (!country) {
    return NextResponse.json({ error: '"country" is required' }, { status: 400 })
  }

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const result = await convex.query(api.health.cuisine.forCountry, { country })
    return NextResponse.json(result)
  } catch (error) {
    console.error("[well-being/cuisine] read failed:", error)
    const message = error instanceof Error ? error.message : "Failed to read dishes"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

/**
 * Two shapes, because they are two different acts.
 *
 * `{ dish }` is a person saying "we eat this" — a vote, and voting again takes
 * it back. `{ dishes }` is a starter list from whatever model the phone is
 * using, written once for a country that has none, carrying no votes at all.
 */
export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const body = await request.json().catch(() => null)
  const country = typeof body?.country === "string" ? body.country.trim() : ""
  if (!country) {
    return NextResponse.json({ error: '"country" is required' }, { status: 400 })
  }

  try {
    const convex = getConvexClient(bearer(request) || caller.token)

    if (Array.isArray(body?.dishes)) {
      const dishes = body.dishes
        .filter((d: unknown): d is string => typeof d === "string")
        .map((d: string) => d.trim())
        .filter(Boolean)
      const result = await convex.mutation(api.health.cuisine.seed, { country, dishes })
      return NextResponse.json(result)
    }

    const dish = typeof body?.dish === "string" ? body.dish.trim() : ""
    if (!dish) {
      return NextResponse.json({ error: '"dish" is required' }, { status: 400 })
    }
    const result = await convex.mutation(api.health.cuisine.suggest, { country, dish })
    return NextResponse.json(result)
  } catch (error) {
    console.error("[well-being/cuisine] write failed:", error)
    const message = error instanceof Error ? error.message : "Failed to save"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
