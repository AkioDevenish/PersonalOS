import path from 'path'
import Database from 'better-sqlite3'
import type { RequestActor } from './request-actor'

export const HEALTH_DB_PATH =
  process.env.HEALTH_DB_PATH || path.join(process.env.HOME || '', 'personal_os/Well Being/data/health.db')

export const HEALTHKIT_SOURCE = 'healthkit'
export const LEGACY_DAILY_SOURCE = 'daily_health.txt'

/** Intraday rows used for charts and hourly Gemma (HealthKit + legacy iCloud export). */
export const INTRADAY_SOURCES_SQL = `('${HEALTHKIT_SOURCE}', '${LEGACY_DAILY_SOURCE}')`

let dbInstance: ReturnType<typeof Database> | null = null

export function getDb() {
  if (!dbInstance) {
    dbInstance = new Database(HEALTH_DB_PATH, { fileMustExist: false })
    dbInstance.pragma('journal_mode = WAL')
  }
  return dbInstance
}

export function sqlString(value: string) {
  return `'${value.replaceAll("'", "''")}'`
}

export async function execSql(sql: string, timeoutMs = 10000) {
  getDb().exec(sql)
}

export async function queryJson<T>(sql: string, timeoutMs = 10000): Promise<T[]> {
  return getDb().prepare(sql).all() as T[]
}

export async function ensureHealthRecordsTable() {
  const ddl = `
    CREATE TABLE IF NOT EXISTS health_metrics (
      date TIMESTAMP NOT NULL,
      metric_type TEXT NOT NULL,
      value REAL NOT NULL,
      source_file TEXT NOT NULL,
      PRIMARY KEY (date, metric_type, source_file)
    );
  `.replace(/\n/g, ' ')
  await execSql(ddl)
}

export type HealthSampleInput = {
  date: string
  metric_type: string
  value: number
  unit?: string | null
}

function normalizeDateForSqlite(isoDate: string): string {
  const d = new Date(isoDate)
  if (Number.isNaN(d.getTime())) {
    throw new Error(`Invalid date: ${isoDate}`)
  }
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

export async function upsertHealthKitSamples(samples: HealthSampleInput[]): Promise<number> {
  await ensureHealthRecordsTable()
  const db = getDb()
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO health_metrics (date, metric_type, value, source_file)
    VALUES (?, ?, ?, ?)
  `)
  
  let count = 0
  const insertMany = db.transaction(() => {
    for (const sample of samples) {
      if (sample.value == null || Number.isNaN(sample.value)) continue;
      const date = normalizeDateForSqlite(sample.date)
      stmt.run(date, sample.metric_type, sample.value, HEALTHKIT_SOURCE);
      count++;
    }
  })
  insertMany()
  return count
}

export async function ensureSaasHealthTables() {
  getDb().exec(`
    CREATE TABLE IF NOT EXISTS health_sync_batches (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      workspace_id TEXT NOT NULL,
      source TEXT NOT NULL,
      device_id TEXT,
      sample_count INTEGER NOT NULL DEFAULT 0,
      received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS health_samples (
      user_id TEXT NOT NULL,
      workspace_id TEXT NOT NULL,
      source TEXT NOT NULL,
      device_id TEXT,
      metric_type TEXT NOT NULL,
      recorded_at TIMESTAMP NOT NULL,
      value REAL NOT NULL,
      unit TEXT,
      sync_batch_id TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, source, metric_type, recorded_at)
    );

    CREATE TABLE IF NOT EXISTS health_privacy_settings (
      user_id TEXT PRIMARY KEY,
      cloud_ai_enabled INTEGER NOT NULL DEFAULT 1,
      ai_runtime_mode TEXT NOT NULL DEFAULT 'server_gemma',
      included_model_package TEXT,
      sync_enabled INTEGER NOT NULL DEFAULT 1,
      retention_days INTEGER,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `)

  for (const column of [
    "ai_runtime_mode TEXT NOT NULL DEFAULT 'server_gemma'",
    'included_model_package TEXT',
  ]) {
    try {
      getDb().exec(`ALTER TABLE health_privacy_settings ADD COLUMN ${column}`)
    } catch {
      /* column already exists */
    }
  }
}

export type SaasHealthSampleInput = HealthSampleInput & {
  source?: string
}

export async function upsertSaasHealthSamples({
  actor,
  deviceId,
  samples,
  source = HEALTHKIT_SOURCE,
}: {
  actor: RequestActor
  deviceId: string | null
  samples: SaasHealthSampleInput[]
  source?: string
}): Promise<{ upserted: number; syncBatchId: string }> {
  await ensureSaasHealthTables()
  const db = getDb()
  const syncBatchId = `${actor.userId}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`

  const batchStmt = db.prepare(`
    INSERT INTO health_sync_batches (id, user_id, workspace_id, source, device_id, sample_count)
    VALUES (?, ?, ?, ?, ?, ?)
  `)
  const sampleStmt = db.prepare(`
    INSERT INTO health_samples (
      user_id, workspace_id, source, device_id, metric_type, recorded_at, value, unit, sync_batch_id, updated_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(user_id, source, metric_type, recorded_at) DO UPDATE SET
      workspace_id = excluded.workspace_id,
      device_id = excluded.device_id,
      value = excluded.value,
      unit = excluded.unit,
      sync_batch_id = excluded.sync_batch_id,
      updated_at = CURRENT_TIMESTAMP
  `)

  let count = 0
  const write = db.transaction(() => {
    batchStmt.run(syncBatchId, actor.userId, actor.workspaceId, source, deviceId, samples.length)

    for (const sample of samples) {
      if (sample.value == null || Number.isNaN(sample.value)) continue
      const recordedAt = normalizeDateForSqlite(sample.date)
      sampleStmt.run(
        actor.userId,
        actor.workspaceId,
        sample.source || source,
        deviceId,
        sample.metric_type,
        recordedAt,
        sample.value,
        sample.unit || null,
        syncBatchId,
      )
      count++
    }
  })

  write()
  return { upserted: count, syncBatchId }
}

export function verifyIngestAuth(request: Request): { ok: true } | { ok: false; status: number; error: string } {
  const secret = process.env.HEALTH_INGEST_SECRET?.trim()
  if (!secret) {
    return { ok: true }
  }
  const header = request.headers.get('authorization')
  const token = header?.startsWith('Bearer ') ? header.slice(7).trim() : null
  if (token !== secret) {
    return { ok: false, status: 401, error: 'Unauthorized: invalid or missing Bearer token' }
  }
  return { ok: true }
}
