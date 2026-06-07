import { NextResponse } from 'next/server'
import { ConvexHttpClient } from "convex/browser"
import { api } from "../../../../../convex/_generated/api"
import type { Id } from "../../../../../convex/_generated/dataModel"

const client = new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL!)

export async function GET() {
  try {
    const contacts = await client.query(api.business.getContacts)
    return NextResponse.json({ contacts })
  } catch (error) {
    console.error('Error reading contacts:', error)
    return NextResponse.json({ error: 'Failed to read contacts' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { name, company, email, phone, status, notes } = body

    if (!name) {
      return NextResponse.json({ error: 'Name is required' }, { status: 400 })
    }

    const id = await client.mutation(api.business.addContact, {
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
    const body = await request.json()
    const { id, name, company, email, phone, status, notes } = body

    if (!id) {
      return NextResponse.json({ error: 'ID is required' }, { status: 400 })
    }

    await client.mutation(api.business.updateContact, {
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
