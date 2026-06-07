import { NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { ConvexHttpClient } from 'convex/browser'
import { api } from "../../../../../convex/_generated/api"

const convex = new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL!)

export async function GET() {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const stats = await convex.query(api.marketing.getStats)
    
    return NextResponse.json({
      total_posts: stats.total,
      published: stats.published,
      drafts: stats.total - stats.published,
      this_week: stats.this_week
    })
  } catch (error) {
    console.error('Error reading marketing stats:', error)
    return NextResponse.json({ error: 'Failed to read marketing stats' }, { status: 500 })
  }
}
