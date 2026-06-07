import { NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { api } from "../../../../../convex/_generated/api"
import type { Id } from "../../../../../convex/_generated/dataModel"
import { getConvexClient } from "@/lib/convex-client"

export async function GET() {
  try {
    const { getToken } = await auth()
    const token = await getToken({ template: 'convex' })
    const contacts = await getConvexClient(token).query(api.business.getContacts)
    return NextResponse.json({ contacts })
  } catch (error) {
    console.error('Error reading contacts:', error)
    return NextResponse.json({ error: 'Failed to read contacts' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const { getToken } = await auth()
    const token = await getToken({ template: 'convex' })
    const body = await request.json()
    const { name, company, email, phone, status, notes } = body

    if (!name) {
      return NextResponse.json({ error: 'Name is required' }, { status: 400 })
    }

    const id = await getConvexClient(token).mutation(api.business.addContact, {
      name,
      company,
      email,
      phone,
      status: status || 'prospect',
      notes,
    })

    return NextResponse.json({ id, name })
  } catch (error) {
    console.error('Error creating contact:', error)
    return NextResponse.json({ error: 'Failed to create contact' }, { status: 500 })
  }
}

export async function PUT(request: Request) {
  try {
    const { getToken } = await auth()
    const token = await getToken({ template: 'convex' })
    const body = await request.json()
    const { id, name, company, email, phone, status, notes } = body

    if (!id) {
      return NextResponse.json({ error: 'ID is required' }, { status: 400 })
    }

    await getConvexClient(token).mutation(api.business.updateContact, {
      id: id as Id<"contacts">,
      name,
      company,
      email,
      phone,
      status,
      notes,
    })

    return NextResponse.json({ success: true, id })
  } catch (error) {
    console.error('Error updating contact:', error)
    return NextResponse.json({ error: 'Failed to update contact' }, { status: 500 })
  }
}
