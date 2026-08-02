import { NextResponse } from "next/server"

export const dynamic = "force-dynamic"

/**
 * RETIRED — replaced by POST /api/health/ingest.
 *
 * This endpoint took the account to write to from an `x-personal-os-user-id`
 * request header, gated only by a single shared bearer token. Anyone holding
 * that token could set the header to any user's id and read or write their
 * health data — a straightforward impersonation hole, on the most sensitive
 * data in the product.
 *
 * It is deliberately not "fixed in place". A client that still points here is
 * a client that still believes it may name its own user, and it needs to be
 * updated rather than silently kept working. The replacement derives identity
 * from a verified Clerk session and offers no way to specify a user at all.
 *
 * 410 rather than 404 so an old build gets an actionable answer instead of
 * looking like a routing mistake.
 */
const GONE = {
  error: "This endpoint has been retired",
  detail:
    "Health ingest now requires a signed-in session. Send samples to /api/health/ingest with a Clerk bearer token; the user is derived from the token and can no longer be set by header.",
  replacement: "/api/health/ingest",
}

export async function POST() {
  return NextResponse.json(GONE, { status: 410 })
}

export async function GET() {
  return NextResponse.json(GONE, { status: 410 })
}
