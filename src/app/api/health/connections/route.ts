import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"
import { oauthProvider, credentialsFor } from "@/lib/health/oauth-providers"
import { canPull } from "@/lib/health/provider-pull"

export const dynamic = "force-dynamic"

/**
 * The connection list, as the phone should see it.
 *
 * Convex knows whether an account is linked. It does not know whether this
 * particular deployment has the client credentials to offer the link in the
 * first place — that lives in the server environment. Without `configured`
 * the app would draw a Connect button for a provider that can only answer 503,
 * which is the exact dead control this replaces.
 */
export async function GET(request: Request) {
  const { userId, getToken } = await auth()
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
  const token = bearer || (await getToken({ template: "convex" }))
  if (!token) {
    return NextResponse.json({ error: "No Convex credential on this request" }, { status: 401 })
  }

  try {
    const convex = getConvexClient(token)
    const rows = (await convex.query(api.health.connections.available, {})) ?? []

    const connections = (rows as any[]).map((r) => {
      const spec = oauthProvider(r.key)
      return {
        ...r,
        configured: spec ? credentialsFor(spec) !== null : false,
        syncable: canPull(r.key),
      }
    })

    return NextResponse.json({ connections })
  } catch (error) {
    console.error("[health/connections] failed:", error)
    const message = error instanceof Error ? error.message : "Failed to load connections"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
