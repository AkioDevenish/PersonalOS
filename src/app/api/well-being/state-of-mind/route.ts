import { NextResponse } from 'next/server'
import Database from 'better-sqlite3'
import path from 'path'
import os from 'os'

const dbPath = path.join(os.homedir(), 'personal_os', 'Well Being', 'data', 'health.db')

export async function GET() {
  try {
    const db = new Database(dbPath)

    // Ensure table exists
    db.exec(`
      CREATE TABLE IF NOT EXISTS state_of_mind_entries (
        id TEXT PRIMARY KEY,
        timestamp TIMESTAMP NOT NULL,
        labels TEXT NOT NULL,
        valence REAL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `)

    // Get recent entries (last 7 days)
    const query = `
      SELECT id, timestamp, labels, valence
      FROM state_of_mind_entries
      WHERE date(timestamp) >= date('now', '-7 days')
      ORDER BY timestamp DESC
      LIMIT 20
    `
    const rows = db.prepare(query).all()
    db.close()

    return NextResponse.json({ success: true, entries: rows })
  } catch (error: any) {
    console.error('Failed to fetch state of mind entries:', error)
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}
