/**
 * Canonical samples → the row shape the Well Being tab already renders.
 *
 * The charts were written against the old SQLite table, whose units came from
 * whatever the first iOS build happened to send: kilometres, km/h, hours, and
 * percentages as 0–1 fractions. The canonical store is metres, m/s, minutes
 * and 0–100.
 *
 * Rather than rewrite 1,600 lines of chart code, convert here. That keeps the
 * UI untouched while the data underneath moves from a SQLite file on one
 * laptop to a per-user Convex table.
 *
 * This is the exact inverse of CanonicalMapper in the iOS app — if you change
 * one, change both.
 */

export type LegacyHealthRecord = {
  date: string
  steps: number | null
  distance_km: number | null
  flights_climbed: number | null
  walking_speed: number | null
  walking_steadiness: number | null
  walking_asymmetry_pct: number | null
  walking_step_length: number | null
  walking_double_support_pct: number | null
  stair_ascent_speed: number | null
  active_energy_burned: number | null
  basal_energy_burned: number | null
  headphone_audio_exposure: number | null
  mindful_session_mins: number | null
  time_in_daylight: number | null
  total_sleep_hours: number | null
  avg_blood_glucose_mgdl: number | null
  dietary_carbohydrates_g: number | null
  insulin_delivery_iu: number | null
  /** Which provider won for this day — shown as provenance. */
  source_file: string
}

export type ResolvedDay = {
  day: string
  metrics: Record<string, { value: number; unit: string; provider: string }>
}

/** canonical metric -> [legacy field, factor to apply] */
const FIELDS: Record<string, [keyof LegacyHealthRecord, number]> = {
  steps: ["steps", 1],
  distance: ["distance_km", 1 / 1000], // m -> km
  flights_climbed: ["flights_climbed", 1],
  walking_speed: ["walking_speed", 3.6], // m/s -> km/h
  walking_steadiness: ["walking_steadiness", 1 / 100], // pct -> fraction
  walking_asymmetry: ["walking_asymmetry_pct", 1 / 100],
  walking_double_support: ["walking_double_support_pct", 1 / 100],
  walking_step_length: ["walking_step_length", 1],
  stair_ascent_speed: ["stair_ascent_speed", 1],
  active_energy: ["active_energy_burned", 1],
  basal_energy: ["basal_energy_burned", 1],
  headphone_audio_exposure: ["headphone_audio_exposure", 1],
  mindful_minutes: ["mindful_session_mins", 1],
  time_in_daylight: ["time_in_daylight", 1],
  sleep_duration: ["total_sleep_hours", 1 / 60], // min -> hours
  blood_glucose: ["avg_blood_glucose_mgdl", 1],
  dietary_carbohydrates: ["dietary_carbohydrates_g", 1],
  insulin_delivery: ["insulin_delivery_iu", 1],
}

function emptyRecord(day: string): LegacyHealthRecord {
  return {
    // the charts parse this as a timestamp, so keep a time component
    date: `${day} 12:00:00`,
    steps: null,
    distance_km: null,
    flights_climbed: null,
    walking_speed: null,
    walking_steadiness: null,
    walking_asymmetry_pct: null,
    walking_step_length: null,
    walking_double_support_pct: null,
    stair_ascent_speed: null,
    active_energy_burned: null,
    basal_energy_burned: null,
    headphone_audio_exposure: null,
    mindful_session_mins: null,
    time_in_daylight: null,
    total_sleep_hours: null,
    avg_blood_glucose_mgdl: null,
    dietary_carbohydrates_g: null,
    insulin_delivery_iu: null,
    source_file: "personal_os",
  }
}

export function toLegacyRecords(days: ResolvedDay[]): LegacyHealthRecord[] {
  return days.map((d) => {
    const row = emptyRecord(d.day)
    const providers = new Set<string>()

    for (const [metric, resolved] of Object.entries(d.metrics)) {
      const mapping = FIELDS[metric]
      if (!mapping) continue
      const [field, factor] = mapping
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(row as any)[field] = resolved.value * factor
      providers.add(resolved.provider)
    }

    // one provider is the common case; name it so the UI can show provenance
    row.source_file = providers.size === 1 ? [...providers][0] : "personal_os"
    return row
  })
}

/** Averages across the window, matching what the old summary query produced. */
export function toLegacySummary(records: LegacyHealthRecord[]) {
  if (records.length === 0) return null

  const numericFields = Object.values(FIELDS).map(([field]) => field)
  const summary: Record<string, number | null> = {}

  for (const field of numericFields) {
    const values = records
      .map((r) => r[field])
      .filter((v): v is number => typeof v === "number" && Number.isFinite(v))
    summary[`avg_${field}`] = values.length
      ? values.reduce((a, b) => a + b, 0) / values.length
      : null
  }

  summary.days = records.length
  return summary
}

/** YYYY-MM-DD for `days` back from today, in the given zone. */
export function rangeFor(days: number, timeZone: string) {
  const fmt = (d: Date) =>
    new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(d)

  const now = new Date()
  const start = new Date(now.getTime() - (days - 1) * 24 * 60 * 60 * 1000)
  return { from: fmt(start), to: fmt(now) }
}
