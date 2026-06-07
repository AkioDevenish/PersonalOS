import { NextResponse } from 'next/server'
import { execSql, queryJson } from '@/lib/health-db'
import { getRequestActor } from '@/lib/request-actor'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const auth = getRequestActor(request)
    if (!auth.ok) {
      return NextResponse.json({ error: auth.error }, { status: auth.status })
    }
    const { actor } = auth
    const { searchParams } = new URL(request.url)
    const period = searchParams.get('period') || 'daily'
    const limit = parseInt(searchParams.get('limit') || '30', 10)
    const expert = searchParams.get('expert')
    let expertFilter = "expert IS NULL OR expert = 'general'"
    if (expert && expert !== 'null' && expert !== 'general') {
      expertFilter = `expert = '${expert.replace(/'/g, "''")}'`
    }

    await execSql(`
      CREATE TABLE IF NOT EXISTS ai_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period TEXT NOT NULL,
        report_text TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `)
    try {
      await execSql('ALTER TABLE ai_reports ADD COLUMN expert TEXT')
    } catch {
      /* column already exists */
    }
    try {
      await execSql('ALTER TABLE ai_reports ADD COLUMN user_id TEXT')
    } catch {
      /* column already exists */
    }
    try {
      await execSql('ALTER TABLE ai_reports ADD COLUMN workspace_id TEXT')
    } catch {
      /* column already exists */
    }
    try {
      await execSql('ALTER TABLE ai_reports ADD COLUMN model TEXT')
    } catch {
      /* column already exists */
    }

    const query = `
      SELECT id, period, report_text, created_at, expert, user_id, workspace_id, model
      FROM ai_reports
      WHERE period = '${period.replace(/'/g, "''")}'
      AND ${expertFilter}
      AND (user_id IS NULL OR user_id = '${actor.userId.replace(/'/g, "''")}')
      ORDER BY datetime(created_at) DESC
      LIMIT ${limit}
    `

    const reports = await queryJson<Record<string, unknown>>(query)

    return NextResponse.json({ reports })
  } catch (error) {
    console.error('Error reading AI reports:', error)
    return NextResponse.json({ error: 'Failed to read AI reports' }, { status: 500 })
  }
}
