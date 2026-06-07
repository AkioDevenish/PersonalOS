import { NextResponse } from 'next/server'
import Database from 'better-sqlite3'
import path from 'path'
import os from 'os'
import { randomUUID } from 'crypto'

const dbPath = process.env.HEALTH_DB_PATH || path.join(os.homedir(), 'personal_os', 'Well Being', 'data', 'health.db')

export async function GET() {
  try {
    const db = new Database(dbPath)
    
    // Get today's events
    const today = new Date().toISOString().split('T')[0]
    const query = `
      SELECT id, timestamp, category, intensity, notes 
      FROM metabolic_events 
      WHERE date(timestamp) = ? AND category != 'State of Mind'
      ORDER BY timestamp DESC
    `
    const rows = db.prepare(query).all(today)
    db.close()

    return NextResponse.json({ success: true, events: rows })
  } catch (error: any) {
    console.error('Failed to fetch telemetry events:', error)
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  try {
    const { id } = await request.json()
    if (!id) {
      return NextResponse.json({ success: false, error: 'Event ID is required' }, { status: 400 })
    }

    const db = new Database(dbPath)
    const result = db.prepare('DELETE FROM metabolic_events WHERE id = ?').run(id)
    db.close()

    if (result.changes === 0) {
      return NextResponse.json({ success: false, error: 'Event not found' }, { status: 404 })
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Failed to delete telemetry event:', error)
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const { category, intensity, notes } = await request.json()

    if (!category) {
      return NextResponse.json({ success: false, error: 'Category is required' }, { status: 400 })
    }

    const db = new Database(dbPath)
    const id = randomUUID()
    
    // Use local time for the timestamp
    const now = new Date()
    // Formatting to YYYY-MM-DD HH:MM:SS local time
    const tzOffset = now.getTimezoneOffset() * 60000
    const localISOTime = (new Date(now.getTime() - tzOffset)).toISOString().slice(0, 19).replace('T', ' ')
    
    const stmt = db.prepare(`
      INSERT INTO metabolic_events (id, timestamp, category, intensity, notes)
      VALUES (?, ?, ?, ?, ?)
    `)
    
    stmt.run(id, localISOTime, category, intensity || null, notes || null)
    db.close()

    return NextResponse.json({ success: true, event: { id, timestamp: localISOTime, category, intensity, notes } })
  } catch (error: any) {
    console.error('Failed to ingest telemetry event:', error)
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}
