import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../convex/_generated/api"

export const dynamic = "force-dynamic"

/**
 * One read for whichever pillar the app is showing.
 *
 * Business, Creative and Data each have a Convex module that predates the
 * phone app and was only ever reachable from the web dashboard. Rather than
 * three near-identical routes, this takes the pillar as a parameter and
 * returns whatever that one needs in a single round trip — a phone on a train
 * should not make four calls to draw one screen.
 *
 * Identity is the caller's own bearer token, forwarded to Convex, which is
 * what scopes every one of these queries to their rows.
 */
export async function GET(request: Request) {
  const { userId, getToken } = await auth()
  if (!userId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
  const token = bearer || (await getToken({ template: "convex" }))
  if (!token) {
    return NextResponse.json({ error: "No Convex credential on this request" }, { status: 401 })
  }

  const pillar = new URL(request.url).searchParams.get("pillar")
  const convex = getConvexClient(token)

  try {
    switch (pillar) {
      case "business": {
        const [contacts, pipeline] = await Promise.all([
          convex.query(api.business.getContacts, {}),
          convex.query(api.business.getPipelineSummary, {}),
        ])
        return NextResponse.json({ contacts: contacts ?? [], pipeline: pipeline ?? null })
      }
      case "creative": {
        const [posts, stats] = await Promise.all([
          convex.query(api.marketing.getPosts, { limit: 30 }),
          convex.query(api.marketing.getStats, {}),
        ])
        return NextResponse.json({ posts: posts ?? [], stats: stats ?? null })
      }
      case "data": {
        const [projects, tracker] = await Promise.all([
          convex.query(api.datascience.getProjects, {}),
          convex.query(api.datascience.getTracker, {}),
        ])
        return NextResponse.json({ projects: projects ?? [], tracker: tracker ?? null })
      }
      default:
        return NextResponse.json(
          { error: 'pillar must be one of "business", "creative", "data"' },
          { status: 400 },
        )
    }
  } catch (error) {
    console.error(`[pillars/${pillar}] failed:`, error)
    const message = error instanceof Error ? error.message : "Failed to load"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
