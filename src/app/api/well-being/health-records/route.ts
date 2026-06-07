import { NextResponse } from 'next/server'
import { ensureSaasHealthTables, INTRADAY_SOURCES_SQL, queryJson } from '@/lib/health-db'
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
    const requestedDays = parseInt(searchParams.get('days') || '7', 10)
    const days = Number.isFinite(requestedDays) ? Math.min(Math.max(requestedDays, 1), 365) : 7

    if (actor.authMode === 'saas') {
      await ensureSaasHealthTables()
    }

    const metricSource =
      actor.authMode === 'saas'
        ? `
          SELECT
            recorded_at as date,
            metric_type,
            value,
            source as source_file
          FROM health_samples
          WHERE user_id = '${actor.userId.replaceAll("'", "''")}'
        `
        : `
          SELECT date, metric_type, value, source_file
          FROM health_metrics
          WHERE source_file IN ${INTRADAY_SOURCES_SQL}
        `

    const pivotedCTE = `
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
          source_file
        FROM (${metricSource})
        GROUP BY date, source_file
      )
    `

    const query = `
      ${pivotedCTE}
      SELECT *
      FROM Pivoted
      WHERE datetime(date) >= datetime('now', 'localtime', '-${days} days')
      ORDER BY datetime(date) ASC
    `

    const summaryQuery = `
      ${pivotedCTE}
      SELECT
        MAX(date) as date,
        AVG(steps) as steps,
        AVG(distance_km) as distance_km,
        AVG(flights_climbed) as flights_climbed,
        AVG(walking_speed) as walking_speed,
        AVG(walking_steadiness) as walking_steadiness,
        AVG(walking_asymmetry_pct) as walking_asymmetry_pct,
        AVG(walking_step_length) as walking_step_length,
        AVG(walking_double_support_pct) as walking_double_support_pct,
        AVG(stair_ascent_speed) as stair_ascent_speed,
        SUM(active_energy_burned) as active_energy_burned,
        SUM(basal_energy_burned) as basal_energy_burned,
        AVG(headphone_audio_exposure) as headphone_audio_exposure,
        SUM(mindful_session_mins) as mindful_session_mins,
        SUM(time_in_daylight) as time_in_daylight,
        MAX(total_sleep_hours) as total_sleep_hours
      FROM (
        SELECT date(date) as day,
               MAX(date) as date,
               MAX(steps) as steps,
               MAX(distance_km) as distance_km,
               MAX(flights_climbed) as flights_climbed,
               AVG(walking_speed) as walking_speed,
               AVG(walking_steadiness) as walking_steadiness,
               AVG(walking_asymmetry_pct) as walking_asymmetry_pct,
               AVG(walking_step_length) as walking_step_length,
               AVG(walking_double_support_pct) as walking_double_support_pct,
               AVG(stair_ascent_speed) as stair_ascent_speed,
               MAX(active_energy_burned) as active_energy_burned,
               MAX(basal_energy_burned) as basal_energy_burned,
               MAX(headphone_audio_exposure) as headphone_audio_exposure,
               MAX(mindful_session_mins) as mindful_session_mins,
               MAX(time_in_daylight) as time_in_daylight,
               MAX(total_sleep_hours) as total_sleep_hours
        FROM Pivoted
        WHERE ${days === 1 
          ? "date(date) = date('now', 'localtime')" 
          : `datetime(date) >= datetime('now', 'localtime', '-${days} days')`}
        GROUP BY day
      )
    `

    const [records, summaries] = await Promise.all([
      queryJson<Record<string, unknown>>(query),
      queryJson<Record<string, unknown>>(summaryQuery),
    ])
    
    const summary = summaries[0] || null

    return NextResponse.json({ records, summary })
  } catch (error) {
    console.error('Error reading health records:', error)
    return NextResponse.json({ error: 'Failed to read health records' }, { status: 500 })
  }
}
