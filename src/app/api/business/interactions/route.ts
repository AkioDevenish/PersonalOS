import { NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { ConvexHttpClient } from 'convex/browser'
import { api } from '../../../../../convex/_generated/api'

const convex = new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL!)

export async function GET() {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const interactions = await convex.query(api.business.getInteractions)
    return NextResponse.json({ interactions })
  } catch (error) {
    console.error('Error reading interactions:', error)
    return NextResponse.json({ error: 'Failed to read interactions' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { contact_id, type, notes } = body

    if (!contact_id || !type || !notes) {
      return NextResponse.json({ error: 'contact_id, type, and notes are required' }, { status: 400 })
    }

    const id = await convex.mutation(api.business.addInteraction, {
      contact_id,
      type,
      date: Date.now(),
      notes,
    })

    return NextResponse.json({ id })
  } catch (error) {
    console.error('Error creating interaction:', error)
    return NextResponse.json({ error: 'Failed to create interaction' }, { status: 500 })
  }
}
