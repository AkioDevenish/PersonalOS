import { NextResponse } from 'next/server'
import {
  HEALTHKIT_SOURCE,
  upsertHealthKitSamples,
  upsertSaasHealthSamples,
  type HealthSampleInput,
} from '@/lib/health-db'
import { getRequestActor } from '@/lib/request-actor'
import { internal } from "../../../../../convex/_generated/api"
import { getConvexClient } from "@/lib/convex-client"

function isSample(value: unknown): boolean {
  if (!value || typeof value !== 'object') return false
  const s = value as Record<string, unknown>
  return typeof s.date === 'string' && s.date.length > 0
}

export async function POST(request: Request) {
  try {
    const auth = getRequestActor(request, { requireAuth: true })
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status })
    }
    const { actor } = auth

    const body = await request.json().catch(() => null)
    if (!body || typeof body !== 'object') {
      return NextResponse.json({ success: false, error: 'JSON body required' }, { status: 400 })
    }

    const rawSamples = (body as { samples?: unknown }).samples
    if (!Array.isArray(rawSamples) || rawSamples.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Body must include a non-empty "samples" array' },
        { status: 400 },
      )
    }

    if (rawSamples.length > 500) {
      return NextResponse.json(
        { success: false, error: 'At most 500 samples per request' },
        { status: 400 },
      )
    }

    const samples: HealthSampleInput[] = []
    for (const item of rawSamples) {
      if (!isSample(item)) {
        return NextResponse.json(
          { success: false, error: 'Each sample needs a string "date" (ISO 8601)' },
          { status: 400 },
        )
      }
      
      const s = item as Record<string, unknown>
      
      // If it's already in the new EAV format
      if (typeof s.metric_type === 'string' && typeof s.value === 'number') {
        samples.push({ date: String(s.date), metric_type: s.metric_type, value: s.value })
      } 
      // Backwards compatibility: dynamically flatten the legacy object format into EAV
      else {
        const metricsToCheck = [
          'steps', 'distance_km', 'flights_climbed', 'walking_speed', 'walking_steadiness', 
          'blood_glucose_mgdl', 'dietary_carbohydrates_g', 'insulin_delivery_iu',
          'walking_asymmetry_pct', 'walking_step_length', 'walking_double_support_pct',
          'stair_ascent_speed', 'active_energy_burned', 'basal_energy_burned',
          'headphone_audio_exposure', 'mindful_session_mins', 'time_in_daylight', 'total_sleep_hours'
        ]
        for (const metric of metricsToCheck) {
          if (typeof s[metric] === 'number') {
            samples.push({ date: String(s.date), metric_type: metric, value: s[metric] })
          }
        }
      }
    }

    const deviceId =
      typeof (body as { deviceId?: unknown }).deviceId === 'string'
        ? (body as { deviceId: string }).deviceId
        : null

    let upserted = 0
    let cloudUpserted = 0
    let syncBatchId = ''

    if (actor.authMode === 'saas') {
      const convexRecords = rawSamples.map((item: any) => ({
        timestamp: new Date(item.date).getTime(),
        steps: typeof item.steps === 'number' ? item.steps : undefined,
        distance: typeof item.distance_km === 'number' ? item.distance_km : undefined,
        flights_climbed: typeof item.flights_climbed === 'number' ? item.flights_climbed : undefined,
        walking_speed: typeof item.walking_speed === 'number' ? item.walking_speed : undefined,
        walking_steadiness: typeof item.walking_steadiness === 'number' ? item.walking_steadiness : undefined,
        source: HEALTHKIT_SOURCE,
      }))
      
      const result = await getConvexClient().mutation(
        internal.wellbeing.syncHealthDataInternal, {
          userId: actor.userId,
          records: convexRecords,
        }
      )
      cloudUpserted = result.count
      upserted = result.count
      syncBatchId = `saas-${Date.now()}`
    } else {
      upserted = await upsertHealthKitSamples(samples)
      const saasWrite = await upsertSaasHealthSamples({ actor, deviceId, samples })
      cloudUpserted = saasWrite.upserted
      syncBatchId = saasWrite.syncBatchId
    }

    // Store state_of_mind_labels in a dedicated table (separate from metabolic_events)
    if (actor.authMode === 'local') {
      try {
        const { getDb } = await import('@/lib/health-db')
        const db = getDb()
        db.exec(`
          CREATE TABLE IF NOT EXISTS state_of_mind_entries (
            id TEXT PRIMARY KEY,
            timestamp TIMESTAMP NOT NULL,
            labels TEXT NOT NULL,
            valence REAL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `)
        
        for (const item of rawSamples) {
          const s = item as Record<string, unknown>
          if (typeof s.state_of_mind_labels === 'string' && s.state_of_mind_labels.length > 0) {
            const stmt = db.prepare(`
              INSERT OR REPLACE INTO state_of_mind_entries (id, timestamp, labels, valence)
              VALUES (?, ?, ?, ?)
            `)
            const id = `som-${s.date}`
            // Extract valence if provided, otherwise null
            const valence = typeof s.state_of_mind_valence === 'number' ? s.state_of_mind_valence : null
            stmt.run(id, String(s.date).replace('T', ' ').slice(0, 19), s.state_of_mind_labels, valence)
          }
        }

        // Clean up any legacy state_of_mind entries from metabolic_events
        try {
          db.prepare(`DELETE FROM metabolic_events WHERE category = 'State of Mind'`).run()
        } catch { /* table may not exist yet */ }
      } catch (somErr) {
        console.error('Failed to store state of mind entries', somErr)
      }
    }

    const origin = new URL(request.url).origin
    fetch(`${origin}/api/well-being/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(request.headers.get('authorization')
          ? { authorization: request.headers.get('authorization') as string }
          : {}),
        'x-personal-os-user-id': actor.userId,
        'x-personal-os-workspace-id': actor.workspaceId,
      },
      body: JSON.stringify({ auto: true, background: true }),
    }).catch((autoErr) => console.error('Failed to start automatic signal reports', autoErr))

    return NextResponse.json({
      success: true,
      upserted,
      cloudUpserted: cloudUpserted,
      syncBatchId: syncBatchId,
      source: HEALTHKIT_SOURCE,
      deviceId,
      userId: actor.userId,
      workspaceId: actor.workspaceId,
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Ingest failed'
    console.error('Health ingest failed:', error)
    return NextResponse.json({ success: false, error: message }, { status: 500 })
  }
}

export async function GET() {
  return NextResponse.json({
    endpoint: 'POST /api/well-being/ingest',
    auth: process.env.PERSONAL_OS_API_TOKEN || process.env.HEALTH_INGEST_SECRET
      ? 'Authorization: Bearer <PERSONAL_OS_API_TOKEN or HEALTH_INGEST_SECRET>'
      : 'none in local mode (set PERSONAL_OS_API_TOKEN in production)',
    headers: {
      'x-personal-os-user-id': 'required when PERSONAL_OS_AUTH_MODE=saas',
      'x-personal-os-workspace-id': 'optional workspace id',
    },
    body: {
      deviceId: 'optional string',
      samples: [
        {
          date: 'ISO 8601 datetime',
          metric_type: 'string',
          value: 'number',
        },
      ],
    },
  })
}
