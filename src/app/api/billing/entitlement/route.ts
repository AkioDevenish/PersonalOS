import { NextResponse } from "next/server"
import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../../../convex/_generated/api"

export const dynamic = "force-dynamic"

/**
 * What this user currently has. The app reads its paywall state from here
 * rather than from StoreKit, so entitlement always reflects what the server
 * verified rather than what a device claims.
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
    const entitlement = await convex.query(api.billing.entitlements.mine, {})
    return NextResponse.json(entitlement)
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to read entitlement"
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
