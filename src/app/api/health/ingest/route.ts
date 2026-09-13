import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"

/**
 * Device ingest — the iOS / Android bridge uploading its own user's samples.
 *
 * Identity comes from a verified Clerk session token and nothing else. The
 * older /api/well-being/ingest took the user from an `x-personal-os-user-id`
 * header behind one shared secret, which let any holder of that secret read or
 * write any account's health data. There is deliberately no way to name a
 * different user here: whoever the token says you are is whose data you write.
 *
 * The app authenticates with Clerk's mobile SDK and sends the Convex-templated
 * JWT as a Bearer token.
 */

const MAX_SAMPLES = 1000

export async function POST(request: Request) {
  const { userId, getToken } = await auth()

  if (!userId) {
    return NextResponse.json(
      { success: false, error: "Unauthorized" },
      { status: 401 },
    )
  }

  const body = await request.json().catch(() => null)
  if (!body || typeof body !== "object") {
    return NextResponse.json(
      { success: false, error: "JSON body required" },
      { status: 400 },
    )
  }

  const { provider, samples, timeZone, cursor } = body as {
    provider?: unknown
    samples?: unknown
    timeZone?: unknown
    cursor?: unknown
  }

  if (typeof provider !== "string" || !provider) {
    return NextResponse.json(
      { success: false, error: '"provider" is required' },
      { status: 400 },
    )
  }
  if (!Array.isArray(samples) || samples.length === 0) {
    return NextResponse.json(
      { success: false, error: '"samples" must be a non-empty array' },
      { status: 400 },
    )
  }
  if (samples.length > MAX_SAMPLES) {
    return NextResponse.json(
      { success: false, error: `At most ${MAX_SAMPLES} samples per request` },
      { status: 413 },
    )
  }

  try {
    /**
     * Convex needs a JWT minted from the "convex" template. The phone already
     * fetched one and sent it as its bearer credential, so forward that.
     *
     * Re-minting via getToken() only works when the request carries a Clerk
     * session cookie; for a bearer-authenticated call there is no session to
     * mint from and it returns null. The client then falls back to no auth at
     * all, and Convex — correctly — refuses the write. That surfaced as an
     * opaque 500 rather than an auth error, because it failed inside the
     * mutation rather than at the door.
     */
    const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
    const token = bearer || (await getToken({ template: "convex" }))

    if (!token) {
      return NextResponse.json(
        { success: false, error: "No Convex credential on this request" },
        { status: 401 },
      )
    }

    const convex = getConvexClient(token)

    const result = await convex.mutation(api.health.samples.ingest, {
      provider,
      samples,
      timeZone: typeof timeZone === "string" ? timeZone : undefined,
      cursor: typeof cursor === "string" ? cursor : undefined,
    })

    // Rejections are reported, not fatal: one bad sample in a batch of 500
    // shouldn't cost the phone the whole upload, but the app needs to see
    // them or a mis-mapped metric would fail silently forever.
    return NextResponse.json({ success: true, ...result })
  } catch (error) {
    console.error("[health/ingest] failed:", error)
    const message = error instanceof Error ? error.message : "Ingest failed"
    return NextResponse.json({ success: false, error: message }, { status: 500 })
  }
}
