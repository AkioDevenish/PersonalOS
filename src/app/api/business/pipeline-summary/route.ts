import { NextResponse } from 'next/server'
import { ConvexHttpClient } from "convex/browser"
import { api } from "../../../../../convex/_generated/api"

const client = new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL!)

export async function GET() {
  try {
    const result = await client.query(api.business.getPipelineSummary)
    return NextResponse.json(result)
  } catch (error) {
    console.error('Error reading pipeline summary:', error)
    return NextResponse.json({ error: 'Failed to read pipeline summary' }, { status: 500 })
  }
}
