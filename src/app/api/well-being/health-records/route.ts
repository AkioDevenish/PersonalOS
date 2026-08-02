import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import {
  toLegacyRecords,
  toLegacySummary,
  rangeFor,
  type ResolvedDay,
} from "@/lib/health/legacy-shape"

export const dynamic = "force-dynamic"

/**
 * Health records for the Well Being tab.
 *
 * Now reads the per-user Convex store through the source resolver instead of a
 * SQLite file. Two things change as a result:
 *
 *  - Identity comes from the Clerk session. The previous version used
 *    getRequestActor, which read an `x-personal-os-user-id` header and
 *    otherwise fell back to a shared "local-user" — so every signed-in account
 *    read the same rows.
 *  - There is no local database. The old path opened
 *    ~/personal_os/Well Being/data/health.db, which exists on exactly one
 *    machine and cannot exist on a serverless host at all.
 *
 * The response shape is deliberately unchanged so the existing charts keep
 * working. Converting canonical units back to what they expect happens in
 * lib/health/legacy-shape.
 */
export async function GET(request: Request) {
  const { userId, getToken } = await auth()

  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const url = new URL(request.url)
  const requested = Number(url.searchParams.get("days"))
  const days = Number.isFinite(requested) ? Math.min(Math.max(requested, 1), 365) : 7
  // the viewer's clock decides which day "today" is
  const timeZone = url.searchParams.get("tz") || "UTC"

  try {
    const token = await getToken({ template: "convex" })
    const convex = getConvexClient(token)

    const { from, to } = rangeFor(days, timeZone)
    const result = (await convex.query(api.health.resolve.dailyMatrix, {
      from,
      to,
    })) as { days: ResolvedDay[] }

    const records = toLegacyRecords(result.days)
    const summary = toLegacySummary(records)

    return NextResponse.json({ records, summary })
  } catch (error) {
    console.error("Error reading health records:", error)
    const message =
      error instanceof Error ? error.message : "Failed to read health records"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
