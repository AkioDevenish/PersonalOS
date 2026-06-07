import { NextResponse } from 'next/server'
import { execSql, queryJson, sqlString } from '@/lib/health-db'
import { getRequestActor } from '@/lib/request-actor'
import { INCLUDED_DEVICE_MODEL_PACKAGE } from '@/lib/gemma'

const PERIODS = new Set(['daily', 'weekly', 'monthly', 'hourly'])

async function ensureAiReportsSchema() {
  await execSql(`
    CREATE TABLE IF NOT EXISTS ai_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      period TEXT NOT NULL,
      report_text TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `)

  for (const column of [
    'expert TEXT',
    'user_id TEXT',
    'workspace_id TEXT',
    'model TEXT',
    'source TEXT',
    'model_package TEXT',
  ]) {
    try {
      await execSql(`ALTER TABLE ai_reports ADD COLUMN ${column}`)
    } catch {
      /* column already exists */
    }
  }
}

export async function POST(request: Request) {
  try {
    const auth = getRequestActor(request, { requireAuth: true })
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status })
    }

    const body = (await request.json().catch(() => null)) as Record<string, unknown> | null
    if (!body || typeof body.report_text !== 'string' || !body.report_text.trim()) {
      return NextResponse.json(
        { success: false, error: 'Body must include report_text from the on-device Gemma package' },
        { status: 400 },
      )
    }

    const requestedPeriod = typeof body.period === 'string' ? body.period : 'daily'
    const period = PERIODS.has(requestedPeriod) ? requestedPeriod : 'daily'
    const expert = typeof body.expert === 'string' ? body.expert : null
    const model = typeof body.model === 'string' ? body.model : 'gemma4-device'
    const modelPackage =
      typeof body.model_package === 'string' ? body.model_package : INCLUDED_DEVICE_MODEL_PACKAGE

    await ensureAiReportsSchema()
    await execSql(`
      INSERT INTO ai_reports (
        period, report_text, created_at, expert, user_id, workspace_id, model, source, model_package
      )
      VALUES (
        ${sqlString(period)},
        ${sqlString(body.report_text.trim())},
        datetime('now', 'localtime'),
        ${expert ? sqlString(expert) : 'NULL'},
        ${sqlString(auth.actor.userId)},
        ${sqlString(auth.actor.workspaceId)},
        ${sqlString(model)},
        'included_device',
        ${sqlString(modelPackage)}
      )
    `)

    const rows = await queryJson<{ id: number }>('SELECT last_insert_rowid() as id')
    return NextResponse.json({
      success: true,
      id: rows[0]?.id,
      period,
      source: 'included_device',
      model,
      modelPackage,
      userId: auth.actor.userId,
      workspaceId: auth.actor.workspaceId,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to save device report'
    console.error('Device Gemma report save failed:', error)
    return NextResponse.json({ success: false, error: message }, { status: 500 })
  }
}
