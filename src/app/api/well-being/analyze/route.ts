import { NextResponse } from 'next/server'
import { INTRADAY_SOURCES_SQL, execSql, queryJson } from '@/lib/health-db'
import {
  DeviceLocalGemmaRequiredError,
  INCLUDED_DEVICE_MODEL_PACKAGE,
  generateWithGemma,
} from '@/lib/gemma'
import { getRequestActor, type RequestActor } from '@/lib/request-actor'
const PERIODS = new Set(['daily', 'weekly', 'monthly', 'hourly'])
const EXPERTS = ['general', 'data_scientist', 'endocrinologist', 'nutritionist', 'strength_coach'] as const

function sqlString(value: string) {
  return `'${value.replaceAll("'", "''")}'`
}

const EXPERT_PERSONAS: Record<string, string> = {
  general: 'Senior Principal Health Architect',
  data_scientist: 'Senior Data Scientist',
  endocrinologist: 'Senior Endocrinologist',
  nutritionist: 'Senior Nutritionist',
  strength_coach: 'Senior Strength Coach',
}

const EXPERT_TAGS: Record<string, string[]> = {
  general: [
    '[BEHAVIORAL PATTERN]: Meaningful change in behavior or routine',
    '[METABOLIC PATTERN]: Non-diagnostic glucose, nutrition, or energy pattern',
    '[RECOVERY SIGNAL]: Strain, sleep, or rest signal worth watching',
    '[POSITIVE SIGNAL]: Positive correlation found',
    '[SENSOR OUTLIER]: Hardware data anomaly',
    '[MOVEMENT TREND]: Asymmetry, steadiness, mobility, or movement change',
    '[ENVIRONMENTAL LOAD]: Audio/daylight impact',
    '[NUTRITION PATTERN]: Nutrition-adjacent pattern correlated with output',
    '[OPTIMIZATION OPTION]: Non-medical routine adjustment to test'
  ],
  data_scientist: [
    '[BEHAVIORAL PATTERN]: Meaningful change in behavior or routine',
    '[CORRELATION HYPOTHESIS]: Positive or negative correlation found',
    '[SENSOR OUTLIER]: Hardware data anomaly',
    '[ENVIRONMENTAL LOAD]: Audio/daylight impact'
  ],
  endocrinologist: [
    '[METABOLIC PATTERN]: Non-diagnostic glucose, nutrition, or energy pattern'
  ],
  nutritionist: [
    '[NUTRITION PATTERN]: Nutrition-adjacent pattern correlated with output'
  ],
  strength_coach: [
    '[MOVEMENT TREND]: Asymmetry, steadiness, mobility, or movement change',
    '[RECOVERY SIGNAL]: Strain, sleep, or rest signal worth watching',
    '[OPTIMIZATION OPTION]: Non-medical routine adjustment to test'
  ]
}

function buildPrompt(period: string, summary: string, expert?: string, targetLabel?: string) {
  const persona = expert ? (EXPERT_PERSONAS[expert] || 'Senior Data Scientist') : 'Senior Data Scientist'
  const allowedTags = expert && EXPERT_TAGS[expert] ? EXPERT_TAGS[expert].join('\n') : Object.values(EXPERT_TAGS).flat().join('\n')

  return `
You are a ${persona} analyzing personal wellness telemetry. Extract high-signal patterns without making diagnoses or treatment claims.
Do NOT use conversational language. No greetings. No encouragement. No markdown headers.

Analyze the following health telemetry for the ${targetLabel || period}:
${summary}

Output exactly 3-5 high-signal patterns. You MUST choose from this strict dictionary of tags to prefix your lines:
${allowedTags}

Format exactly like this for each anomaly:
[TAG_NAME]
Write a fluid paragraph explaining the observation and your data-driven hypothesis.
Then, provide a simple bulleted list of actions or key takeaways.
`
}

type AnalysisWindow = {
  period: string
  label: string
  startSql: string
  endSql: string
  stateScope: string
}

function getAnalysisWindow(period: string): AnalysisWindow {
  if (period === 'daily') {
    return {
      period,
      label: 'the previous day',
      startSql: "datetime('now', 'localtime', 'start of day', '-1 day')",
      endSql: "datetime('now', 'localtime', 'start of day')",
      stateScope: 'previous_day',
    }
  }

  if (period === 'weekly') {
    return {
      period,
      label: 'the previous completed week',
      startSql: "datetime('now', 'localtime', 'weekday 1', '-14 days')",
      endSql: "datetime('now', 'localtime', 'weekday 1', '-7 days')",
      stateScope: 'previous_week',
    }
  }

  if (period === 'monthly') {
    return {
      period,
      label: 'the previous completed month',
      startSql: "datetime('now', 'localtime', 'start of month', '-1 month')",
      endSql: "datetime('now', 'localtime', 'start of month')",
      stateScope: 'previous_month',
    }
  }

  return {
    period,
    label: 'the latest hourly window',
    startSql: "datetime('now', 'localtime', '-30 hours')",
    endSql: "datetime('now', 'localtime', '+1 minute')",
    stateScope: 'recent_hours',
  }
}

async function getHealthSummary(period: string) {
  const window = getAnalysisWindow(period)
  const query = `
    WITH Pivoted AS (
      SELECT
        date(date) as day,
        MAX(CASE WHEN metric_type = 'steps' THEN value END) as steps,
        MAX(CASE WHEN metric_type = 'distance_km' THEN value END) as distance_km,
        MAX(CASE WHEN metric_type = 'flights_climbed' THEN value END) as flights_climbed,
        AVG(CASE WHEN metric_type = 'walking_speed' THEN value END) as walking_speed,
        AVG(CASE WHEN metric_type = 'walking_steadiness' THEN value END) as walking_steadiness,
        AVG(CASE WHEN metric_type = 'walking_asymmetry_pct' THEN value END) as walking_asymmetry_pct,
        AVG(CASE WHEN metric_type = 'walking_step_length' THEN value END) as walking_step_length,
        AVG(CASE WHEN metric_type = 'walking_double_support_pct' THEN value END) as walking_double_support_pct,
        AVG(CASE WHEN metric_type = 'stair_ascent_speed' THEN value END) as stair_ascent_speed,
        MAX(CASE WHEN metric_type = 'active_energy_burned' THEN value END) as active_energy_burned,
        MAX(CASE WHEN metric_type = 'basal_energy_burned' THEN value END) as basal_energy_burned,
        MAX(CASE WHEN metric_type = 'headphone_audio_exposure' THEN value END) as headphone_audio_exposure,
        MAX(CASE WHEN metric_type = 'mindful_session_mins' THEN value END) as mindful_session_mins,
        MAX(CASE WHEN metric_type = 'time_in_daylight' THEN value END) as time_in_daylight,
        MAX(CASE WHEN metric_type = 'total_sleep_hours' THEN value END) as total_sleep_hours,
        ROUND(AVG(CASE WHEN metric_type = 'blood_glucose_mgdl' THEN value END), 1) as avg_blood_glucose_mgdl,
        MAX(CASE WHEN metric_type = 'dietary_carbohydrates_g' THEN value END) as dietary_carbohydrates_g,
        MAX(CASE WHEN metric_type = 'insulin_delivery_iu' THEN value END) as insulin_delivery_iu
      FROM health_metrics
      WHERE source_file IN ${INTRADAY_SOURCES_SQL}
        AND datetime(date) >= ${window.startSql}
        AND datetime(date) < ${window.endSql}
      GROUP BY date(date)
    )
    SELECT
      MIN(day) as start_day,
      MAX(day) as end_day,
      COUNT(*) as days_with_data,
      AVG(steps) as avg_steps,
      MAX(steps) as max_steps,
      AVG(distance_km) as avg_distance_km,
      AVG(flights_climbed) as avg_flights_climbed,
      AVG(walking_speed) as avg_walking_speed,
      AVG(walking_steadiness) as avg_walking_steadiness,
      AVG(walking_asymmetry_pct) as avg_walking_asymmetry_pct,
      AVG(walking_step_length) as avg_walking_step_length,
      AVG(walking_double_support_pct) as avg_walking_double_support_pct,
      AVG(stair_ascent_speed) as avg_stair_ascent_speed,
      AVG(active_energy_burned) as avg_active_energy_burned,
      AVG(basal_energy_burned) as avg_basal_energy_burned,
      AVG(headphone_audio_exposure) as avg_headphone_audio_exposure,
      AVG(mindful_session_mins) as avg_mindful_session_mins,
      AVG(time_in_daylight) as avg_time_in_daylight,
      AVG(total_sleep_hours) as avg_total_sleep_hours,
      AVG(avg_blood_glucose_mgdl) as avg_blood_glucose_mgdl,
      AVG(dietary_carbohydrates_g) as avg_dietary_carbohydrates_g,
      AVG(insulin_delivery_iu) as avg_insulin_delivery_iu
    FROM Pivoted
  `
  const rows = await queryJson<Record<string, unknown>>(query)
  const row = rows[0] || {}
  
  // Filter out null values so the LLM doesn't complain about missing data
  const cleanedRow = Object.fromEntries(
    Object.entries(row).filter((entry) => entry[1] !== null)
  )

  return {
    summary: JSON.stringify({ window: window.label, ...cleanedRow }, null, 2),
    fingerprint: JSON.stringify(cleanedRow),
    window,
    hasData: Number(row.days_with_data || 0) > 0,
  }
}

async function askGemma(prompt: string) {
  const { text, model } = await generateWithGemma({ prompt, temperature: 0.2 })
  return { report: text, model }
}

const HOURLY_STATE_KEY = 'last_hourly_daily_snapshot'

async function ensureAnalysisStateTable() {
  const ddl = `
    CREATE TABLE IF NOT EXISTS health_analysis_state (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `.replace(/\n/g, ' ')
  await execSql(ddl)
}

async function getIntradayDailyHealthRows(): Promise<Record<string, unknown>[]> {
  const query = `
    WITH Pivoted AS (
      SELECT
        date,
        MAX(CASE WHEN metric_type = 'steps' THEN value END) as steps,
        MAX(CASE WHEN metric_type = 'distance_km' THEN value END) as distance_km,
        MAX(CASE WHEN metric_type = 'flights_climbed' THEN value END) as flights_climbed,
        MAX(CASE WHEN metric_type = 'walking_speed' THEN value END) as walking_speed,
        MAX(CASE WHEN metric_type = 'walking_steadiness' THEN value END) as walking_steadiness,
        MAX(CASE WHEN metric_type = 'walking_asymmetry_pct' THEN value END) as walking_asymmetry_pct,
        MAX(CASE WHEN metric_type = 'walking_step_length' THEN value END) as walking_step_length,
        MAX(CASE WHEN metric_type = 'walking_double_support_pct' THEN value END) as walking_double_support_pct,
        MAX(CASE WHEN metric_type = 'stair_ascent_speed' THEN value END) as stair_ascent_speed,
        MAX(CASE WHEN metric_type = 'active_energy_burned' THEN value END) as active_energy_burned,
        MAX(CASE WHEN metric_type = 'basal_energy_burned' THEN value END) as basal_energy_burned,
        MAX(CASE WHEN metric_type = 'headphone_audio_exposure' THEN value END) as headphone_audio_exposure,
        MAX(CASE WHEN metric_type = 'mindful_session_mins' THEN value END) as mindful_session_mins,
        MAX(CASE WHEN metric_type = 'time_in_daylight' THEN value END) as time_in_daylight,
        MAX(CASE WHEN metric_type = 'total_sleep_hours' THEN value END) as total_sleep_hours,
        ROUND(AVG(CASE WHEN metric_type = 'blood_glucose_mgdl' THEN value END), 1) as avg_blood_glucose_mgdl,
        MAX(CASE WHEN metric_type = 'dietary_carbohydrates_g' THEN value END) as dietary_carbohydrates_g,
        MAX(CASE WHEN metric_type = 'insulin_delivery_iu' THEN value END) as insulin_delivery_iu,
        source_file
      FROM health_metrics
      WHERE source_file IN ${INTRADAY_SOURCES_SQL}
      GROUP BY date, source_file
    )
    SELECT date, steps, distance_km, flights_climbed, walking_speed, walking_steadiness, walking_asymmetry_pct, walking_step_length, walking_double_support_pct, stair_ascent_speed, active_energy_burned, basal_energy_burned, headphone_audio_exposure, mindful_session_mins, time_in_daylight, total_sleep_hours, avg_blood_glucose_mgdl, dietary_carbohydrates_g, insulin_delivery_iu
    FROM Pivoted
    WHERE (
        date(date) = date('now', 'localtime')
        OR datetime(date) >= datetime('now', 'localtime', '-30 hours')
      )
    ORDER BY datetime(date) ASC;
  `.replace(/\n/g, ' ')
  return queryJson<Record<string, unknown>>(query)
}

function hourlyBundleFingerprint(rows: Record<string, unknown>[]): string {
  return rows.map((r) => `${String(r.date)}#${String(r.steps ?? '')}`).join('|')
}

async function countReports(period: string, actor: RequestActor, expert?: string): Promise<number> {
  await ensureAiReportsSchema()
  const expertFilter = expert ? `AND expert = ${sqlString(expert)}` : ''
  const res = await queryJson<{ count: number }>(`
    SELECT COUNT(*) as count
    FROM ai_reports
    WHERE period = ${sqlString(period)}
      AND (user_id IS NULL OR user_id = ${sqlString(actor.userId)})
      ${expertFilter};
  `)
  return res[0]?.count || 0
}

async function getAnalysisState(key: string): Promise<string | null> {
  const q = `SELECT value FROM health_analysis_state WHERE key = ${sqlString(key)};`
  const res = await queryJson<{ value?: string }>(q)
  const v = res[0]?.value || ''
  return v.length ? v : null
}

async function setAnalysisState(key: string, value: string) {
  const sql = `
    INSERT INTO health_analysis_state (key, value, updated_at)
    VALUES (${sqlString(key)}, ${sqlString(value)}, datetime('now', 'localtime'))
    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
  `.replace(/\n/g, ' ')
  await execSql(sql)
}

function buildHourlyPrompt(summaryJson: string, expert?: string) {
  const currentTime = new Date().toISOString()
  const persona = expert ? (EXPERT_PERSONAS[expert] || 'Senior Data Scientist') : 'Senior Data Scientist'
  const allowedTags = expert && EXPERT_TAGS[expert] ? EXPERT_TAGS[expert].join('\n') : Object.values(EXPERT_TAGS).flat().join('\n')

  return `
You are a ${persona} analyzing personal wellness telemetry. Extract high-signal patterns without making diagnoses or treatment claims.
Do NOT use conversational language. No greetings. No encouragement. No markdown headers.

The current time is: ${currentTime}.
Analyze the following intraday health telemetry snapshots from the last 30 hours:
${summaryJson}

CRITICAL: ONLY flag anomalies that occurred in the most recent timestamps (today). Do NOT re-report anomalies that clearly happened yesterday unless they are actively continuing into today.

Output exactly 3-5 high-signal patterns. You MUST choose from this strict dictionary of tags to prefix your lines:
${allowedTags}

Format exactly like this for each anomaly:
[TAG_NAME]
Write a fluid paragraph explaining the observation and your data-driven hypothesis.
Then, provide a simple bulleted list of actions or key takeaways.
`
}

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
    'target_start TEXT',
    'target_end TEXT',
  ]) {
    try {
      await execSql(`ALTER TABLE ai_reports ADD COLUMN ${column}`)
    } catch {
      /* column already exists */
    }
  }
}

async function saveReport(
  period: string,
  report: string,
  actor: RequestActor,
  model: string,
  expert: string | undefined,
  window: AnalysisWindow,
) {
  await ensureAiReportsSchema()
  const query = `
    INSERT INTO ai_reports (period, report_text, created_at, expert, user_id, workspace_id, model, target_start, target_end)
    VALUES (
      ${sqlString(period)},
      ${sqlString(report)},
      datetime('now', 'localtime'),
      ${expert ? sqlString(expert) : 'NULL'},
      ${sqlString(actor.userId)},
      ${sqlString(actor.workspaceId)},
      ${sqlString(model)},
      ${sqlString(window.startSql)},
      ${sqlString(window.endSql)}
    )
  `
  await execSql(query)
}

async function runAnalysis(period: string, actor: RequestActor, expert?: string) {
  await ensureAnalysisStateTable()

  if (period === 'hourly') {
    const rows = await getIntradayDailyHealthRows()
    if (rows.length === 0) {
      return { success: false, period, expert, skipped: true, reason: 'no_intraday_data' }
    }

    const fingerprint = hourlyBundleFingerprint(rows)
    const stateKey = expert
      ? `${actor.userId}_${HOURLY_STATE_KEY}_${expert}`
      : `${actor.userId}_${HOURLY_STATE_KEY}`
    const hourlyCount = await countReports('hourly', actor, expert)
    const prev = await getAnalysisState(stateKey)

    if (prev === fingerprint && hourlyCount > 0) {
      return { success: true, period: 'hourly', expert, skipped: true, reason: 'intraday_bundle_unchanged' }
    }

    const cleanedRows = rows.map(row =>
      Object.fromEntries(Object.entries(row).filter((entry) => entry[1] !== null))
    )
    const summaryJson = JSON.stringify(cleanedRows, null, 2)
    const prompt = buildHourlyPrompt(summaryJson, expert)
    const { report, model } = await askGemma(prompt)
    await saveReport('hourly', report, actor, model, expert, getAnalysisWindow('hourly'))
    await setAnalysisState(stateKey, fingerprint)

    return { success: true, period: 'hourly', expert, model, skipped: false, report }
  }

  const result = await getHealthSummary(period)
  if (!result.hasData) {
    return { success: false, period, expert, skipped: true, reason: 'no_completed_period_data' }
  }

  const stateKey = `${actor.userId}_${period}_${expert || 'general'}_${result.window.stateScope}_snapshot`
  const prev = await getAnalysisState(stateKey)
  const reportCount = await countReports(period, actor, expert)

  if (prev === result.fingerprint && reportCount > 0) {
    return { success: true, period, expert, skipped: true, reason: 'health_summary_unchanged' }
  }

  const prompt = buildPrompt(period, result.summary, expert, result.window.label)
  const { report, model } = await askGemma(prompt)
  await saveReport(period, report, actor, model, expert, result.window)
  await setAnalysisState(stateKey, result.fingerprint)

  return { success: true, period, expert, model, skipped: false, report }
}

export async function POST(request: Request) {
  try {
    const auth = getRequestActor(request)
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status })
    }
    const { actor } = auth
    const body = (await request.json().catch(() => ({}))) as Record<string, unknown>
    const auto = body.auto === true
    const background = body.background === true
    const requestedPeriod = typeof body.period === 'string' ? body.period : 'daily'
    const period = PERIODS.has(requestedPeriod) ? requestedPeriod : 'daily'
    const expert = typeof body.expert === 'string' ? body.expert : undefined

    if (auto) {
      const jobs: Array<{ period: string; expert: string }> = [
        ...EXPERTS.map((modelExpert) => ({ period: 'hourly', expert: modelExpert })),
        ...EXPERTS.map((modelExpert) => ({ period: 'daily', expert: modelExpert })),
      ]

      const now = new Date()
      if (now.getDay() === 1) {
        jobs.push(...EXPERTS.map((modelExpert) => ({ period: 'weekly', expert: modelExpert })))
      }
      if (now.getDate() === 1) {
        jobs.push(...EXPERTS.map((modelExpert) => ({ period: 'monthly', expert: modelExpert })))
      }

      if (background) {
        void (async () => {
          for (const job of jobs) {
            try {
              await runAnalysis(job.period, actor, job.expert)
            } catch (jobError) {
              console.error('Automatic signal report failed:', job, jobError)
            }
          }
        })()

        return NextResponse.json({
          success: true,
          auto: true,
          background: true,
          queued: jobs.length,
          timestamp: new Date().toISOString(),
        })
      }

      const results = []
      for (const job of jobs) {
        try {
          results.push(await runAnalysis(job.period, actor, job.expert))
        } catch (jobError) {
          results.push({
            success: false,
            period: job.period,
            expert: job.expert,
            skipped: true,
            reason: jobError instanceof Error ? jobError.message : 'analysis_job_failed',
          })
        }
      }

      return NextResponse.json({
        success: true,
        auto: true,
        userId: actor.userId,
        workspaceId: actor.workspaceId,
        generated: results.filter((item) => item.success && !item.skipped).length,
        skipped: results.filter((item) => item.skipped).length,
        results,
        timestamp: new Date().toISOString(),
      })
    }

    if (period === 'hourly') {
      const result = await runAnalysis(period, actor, expert)
      if (!result.success && result.reason === 'no_intraday_data') {
        return NextResponse.json(
          {
            success: false,
            error:
              'No intraday daily_health rows in the database yet. Sync health data (cron or “Sync Health Data”) so SQLite has today’s snapshots, then try again.',
          },
          { status: 400 },
        )
      }

      if (result.skipped) {
        return NextResponse.json({
          success: true,
          period: 'hourly',
          expert,
          skipped: true,
          reason: result.reason,
          timestamp: new Date().toISOString(),
        })
      }

      return NextResponse.json({
        success: true,
        period: 'hourly',
        expert,
        model: result.model,
        userId: actor.userId,
        workspaceId: actor.workspaceId,
        skipped: false,
        report: result.report,
        timestamp: new Date().toISOString(),
      })
    }

    // For Daily, Weekly, Monthly
    const result = await runAnalysis(period, actor, expert)
    if (result.skipped) {
      return NextResponse.json({
        success: result.success,
        period,
        expert,
        skipped: true,
        reason: result.reason,
        timestamp: new Date().toISOString(),
      }, result.success ? undefined : { status: 400 })
    }

    return NextResponse.json({
      success: true,
      period,
      expert,
      model: result.model,
      userId: actor.userId,
      workspaceId: actor.workspaceId,
      skipped: false,
      report: result.report,
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    if (error instanceof DeviceLocalGemmaRequiredError) {
      return NextResponse.json(
        {
          success: false,
          code: 'device_local_gemma_required',
          error: error.message,
          packageId: INCLUDED_DEVICE_MODEL_PACKAGE,
          reportUploadEndpoint: '/api/well-being/device-report',
        },
        { status: 409 },
      )
    }

    const message = error instanceof Error ? error.message : 'Failed to run health analysis'
    console.error('Health analysis failed:', error)
    return NextResponse.json({
      success: false,
      error: message,
    }, { status: 500 })
  }
}
