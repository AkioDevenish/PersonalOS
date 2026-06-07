import { NextResponse } from 'next/server'
import { api } from "../../../../../convex/_generated/api"
import { getConvexClient } from "@/lib/convex-client"

export async function GET() {
  try {
    const result = await getConvexClient().query(api.business.getPipelineSummary)
    return NextResponse.json(result)
  } catch (error) {
    console.error('Error reading pipeline summary:', error)
    return NextResponse.json({ error: 'Failed to read pipeline summary' }, { status: 500 })
  }
}
