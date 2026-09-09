import { NextResponse } from "next/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { requireCaller } from "@/lib/ai/user-model"

export const dynamic = "force-dynamic"

/**
 * The directory of health specialists, and the way into it.
 *
 * GET returns everyone approved and taking questions, plus the caller's own
 * application if they have one — the phone needs both to decide whether it is
 * showing a directory, a form, or a pending notice.
 *
 * Thin, like the rest: Convex decides who is visible and what an application
 * is allowed to claim.
 */

function bearer(request: Request) {
  return request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
}

export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const [specialists, application] = await Promise.all([
      convex.query(api.health.consult.directory, {}),
      convex.query(api.health.consult.myApplication, {}),
    ])
    return NextResponse.json({ specialists, application })
  } catch (error) {
    console.error("[specialists] read failed:", error)
    const message = error instanceof Error ? error.message : "Failed to read the directory"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

/**
 * Hands back a one-time URL the phone uploads a photograph to.
 *
 * A separate verb rather than a field on the application, because the file
 * never travels through here: the device sends it straight to storage and only
 * the resulting id comes back through the application.
 */
export async function PUT(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  try {
    const convex = getConvexClient(bearer(request) || caller.token)
    const url = await convex.mutation(api.health.consult.photoUploadUrl, {})
    return NextResponse.json({ url })
  } catch (error) {
    console.error("[specialists] upload url failed:", error)
    const message = error instanceof Error ? error.message : "Failed"
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
    const result = await convex.mutation(api.health.consult.apply, {
      name: String(body.name ?? ""),
      country: String(body.country ?? ""),
      credentials: String(body.credentials ?? ""),
      bio: String(body.bio ?? ""),
      specialties: Array.isArray(body.specialties)
        ? body.specialties.filter((s: unknown): s is string => typeof s === "string")
        : [],
      photo: typeof body.photo === "string" ? (body.photo as never) : undefined,
      price_credits: Number(body.price_credits ?? 0),
      active: body.active !== false,
    })
    return NextResponse.json(result)
  } catch (error) {
    console.error("[specialists] application failed:", error)
    const message = error instanceof Error ? error.message : "Failed to apply"
    // A rejected application is the applicant's to fix, so the phone can show
    // the reason rather than a generic failure.
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
