import { NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { api } from "../../../../../convex/_generated/api"
import { getConvexClient } from "@/lib/convex-client"

export async function GET(request: Request) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const limit = parseInt(searchParams.get('limit') || '20')

    const posts = await getConvexClient().query(api.marketing.getPosts, { limit })
    return NextResponse.json({ posts })
  } catch (error) {
    console.error('Error reading posts:', error)
    return NextResponse.json({ error: 'Failed to read posts' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { bullets, platform, topic, mood, content, published } = body

    if (!platform || !content) {
      return NextResponse.json({ error: 'platform and content are required' }, { status: 400 })
    }

    const id = await getConvexClient().mutation(api.marketing.addPost, {
      content,
      platform,
      topic,
      mood,
      bullets,
      published: published || false,
    })

    return NextResponse.json({ id })
  } catch (error) {
    console.error('Error creating post:', error)
    return NextResponse.json({ error: 'Failed to create post' }, { status: 500 })
  }
}
