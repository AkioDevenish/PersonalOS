import { NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { api } from '../../../../../convex/_generated/api'
import { getConvexClient } from "@/lib/convex-client"

export async function GET() {
  try {
    const { getToken } = await auth()
    const token = await getToken({ template: 'convex' })

    const interactions = await getConvexClient(token).query(api.business.getInteractions)
    return NextResponse.json({ interactions })
  } catch (error) {
    console.error('Error reading interactions:', error)
    return NextResponse.json({ error: 'Failed to read interactions' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const { getToken } = await auth()
    const token = await getToken({ template: 'convex' })
    const body = await request.json()
    const { contact_id, type, notes } = body

    if (!contact_id || !type || !notes) {
      return NextResponse.json({ error: 'contact_id, type, and notes are required' }, { status: 400 })
    }

    const id = await getConvexClient(token).mutation(api.business.addInteraction, {
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
