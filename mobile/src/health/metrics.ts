/**
 * The canonical health vocabulary, shared with the backend.
 *
 * This mirrors convex/health/metrics.ts. It is duplicated rather than imported
 * because the Convex file lives in a different tsconfig and pulls in server
 * types Metro can't bundle — but the two MUST agree: the ingest mutation
 * rejects any sample whose unit doesn't match, rather than guessing at a
 * conversion. That check is what turns a mistake here into a visible rejection
 * instead of a number that is silently wrong by a factor of a thousand.
 */

export const METRIC_UNITS = {
  steps: "count",
  distance: "m",
  flights_climbed: "count",
  active_energy: "kcal",
  basal_energy: "kcal",
  exercise_minutes: "min",

  sleep_duration: "min",
  sleep_deep: "min",
  sleep_rem: "min",
  sleep_awake: "min",
  sleep_efficiency: "pct",

  heart_rate: "bpm",
  resting_heart_rate: "bpm",
  hrv: "ms",
  respiratory_rate: "brpm",
  spo2: "pct",
  vo2_max: "ml/kg/min",

  body_weight: "kg",
  body_fat: "pct",

  blood_glucose: "mg/dL",
  dietary_carbohydrates: "g",
  insulin_delivery: "IU",

  walking_speed: "m/s",
  walking_steadiness: "pct",
  walking_asymmetry: "pct",
  walking_step_length: "m",
  walking_double_support: "pct",
  stair_ascent_speed: "m/s",
  headphone_audio_exposure: "dB",
  mindful_minutes: "min",
  time_in_daylight: "min",
} as const

export type MetricKey = keyof typeof METRIC_UNITS

/** What the ingest endpoint accepts. */
export type Sample = {
  metric: MetricKey
  value: number
  /** Must equal METRIC_UNITS[metric] or the server rejects it. */
  unit: string
  /** Epoch milliseconds. */
  recorded_at: number
  period_end?: number
  external_id?: string
  device?: string
}

/**
 * Build a sample with the correct unit attached, so a caller cannot pass a
 * mismatched one by accident.
 */
export function sample(
  metric: MetricKey,
  value: number,
  recordedAt: number,
  extra: Partial<Pick<Sample, "period_end" | "external_id" | "device">> = {},
): Sample | null {
  if (!Number.isFinite(value) || !Number.isFinite(recordedAt)) return null
  return {
    metric,
    value,
    unit: METRIC_UNITS[metric],
    recorded_at: Math.round(recordedAt),
    ...extra,
  }
}
