/**
 * Apple Health export → canonical samples.
 *
 * Health app → profile → Export All Health Data produces a zip containing
 * export.xml, a flat list of <Record/> elements covering every sample Apple
 * has ever stored. It is routinely hundreds of megabytes and millions of rows.
 *
 * Two things make it awkward:
 *
 *  - Units follow the exporting phone's locale. The same walk is "km" for one
 *    user and "mi" for another, so the unit attribute must be honoured rather
 *    than assumed.
 *  - Dates are "2026-07-01 08:00:00 +0100", which is not ISO 8601 and does not
 *    parse reliably across engines.
 *
 * Kept free of DOM and worker APIs so it can be unit tested directly.
 */

export type ParsedRecord = {
  type: string
  unit: string | null
  startDate: string
  value: string
}

export type CanonicalPoint = {
  metric: string
  value: number
  unit: string
  recorded_at: number
}

/** Canonical unit per metric — must match METRICS in convex/health/metrics.ts. */
type Conversion = { metric: string; unit: string; from: Record<string, number> }

/**
 * `from` maps an Apple unit string to the factor that converts it to canonical.
 * A unit absent from the map means we don't know the conversion and the sample
 * is dropped rather than guessed at.
 */
const TYPES: Record<string, Conversion> = {
  HKQuantityTypeIdentifierStepCount: {
    metric: "steps", unit: "count", from: { count: 1 },
  },
  HKQuantityTypeIdentifierDistanceWalkingRunning: {
    metric: "distance", unit: "m", from: { m: 1, km: 1000, mi: 1609.344, ft: 0.3048, yd: 0.9144 },
  },
  HKQuantityTypeIdentifierFlightsClimbed: {
    metric: "flights_climbed", unit: "count", from: { count: 1 },
  },
  HKQuantityTypeIdentifierActiveEnergyBurned: {
    metric: "active_energy", unit: "kcal", from: { kcal: 1, Cal: 1, kJ: 0.239006 },
  },
  HKQuantityTypeIdentifierBasalEnergyBurned: {
    metric: "basal_energy", unit: "kcal", from: { kcal: 1, Cal: 1, kJ: 0.239006 },
  },
  HKQuantityTypeIdentifierAppleExerciseTime: {
    metric: "exercise_minutes", unit: "min", from: { min: 1, sec: 1 / 60, hr: 60 },
  },
  HKQuantityTypeIdentifierHeartRate: {
    metric: "heart_rate", unit: "bpm", from: { "count/min": 1, bpm: 1 },
  },
  HKQuantityTypeIdentifierRestingHeartRate: {
    metric: "resting_heart_rate", unit: "bpm", from: { "count/min": 1, bpm: 1 },
  },
  HKQuantityTypeIdentifierHeartRateVariabilitySDNN: {
    metric: "hrv", unit: "ms", from: { ms: 1, s: 1000 },
  },
  HKQuantityTypeIdentifierRespiratoryRate: {
    metric: "respiratory_rate", unit: "brpm", from: { "count/min": 1 },
  },
  HKQuantityTypeIdentifierOxygenSaturation: {
    // Apple exports this as a fraction with unit "%" meaning 0–1
    metric: "spo2", unit: "pct", from: { "%": 100 },
  },
  HKQuantityTypeIdentifierVO2Max: {
    metric: "vo2_max", unit: "ml/kg/min", from: { "mL/min·kg": 1, "ml/kg·min": 1, "mL/kg·min": 1 },
  },
  HKQuantityTypeIdentifierBodyMass: {
    metric: "body_weight", unit: "kg", from: { kg: 1, lb: 0.45359237, st: 6.35029318, g: 0.001 },
  },
  HKQuantityTypeIdentifierBodyFatPercentage: {
    metric: "body_fat", unit: "pct", from: { "%": 100 },
  },
  HKQuantityTypeIdentifierBloodGlucose: {
    metric: "blood_glucose", unit: "mg/dL", from: { "mg/dL": 1, "mmol<180.15588000005408>/L": 18.0155, "mmol/L": 18.0155 },
  },
  HKQuantityTypeIdentifierDietaryCarbohydrates: {
    metric: "dietary_carbohydrates", unit: "g", from: { g: 1, mg: 0.001 },
  },
  HKQuantityTypeIdentifierInsulinDelivery: {
    metric: "insulin_delivery", unit: "IU", from: { IU: 1 },
  },
  HKQuantityTypeIdentifierWalkingSpeed: {
    metric: "walking_speed", unit: "m/s", from: { "m/s": 1, "km/hr": 1 / 3.6, "mi/hr": 0.44704 },
  },
  HKQuantityTypeIdentifierAppleWalkingSteadiness: {
    metric: "walking_steadiness", unit: "pct", from: { "%": 100 },
  },
  HKQuantityTypeIdentifierWalkingAsymmetryPercentage: {
    metric: "walking_asymmetry", unit: "pct", from: { "%": 100 },
  },
  HKQuantityTypeIdentifierWalkingDoubleSupportPercentage: {
    metric: "walking_double_support", unit: "pct", from: { "%": 100 },
  },
  HKQuantityTypeIdentifierWalkingStepLength: {
    metric: "walking_step_length", unit: "m", from: { m: 1, cm: 0.01, in: 0.0254 },
  },
  HKQuantityTypeIdentifierStairAscentSpeed: {
    metric: "stair_ascent_speed", unit: "m/s", from: { "m/s": 1 },
  },
  HKQuantityTypeIdentifierHeadphoneAudioExposure: {
    metric: "headphone_audio_exposure", unit: "dB", from: { dBASPL: 1, dB: 1 },
  },
  HKQuantityTypeIdentifierTimeInDaylight: {
    metric: "time_in_daylight", unit: "min", from: { min: 1, sec: 1 / 60, hr: 60 },
  },
  HKCategoryTypeIdentifierMindfulSession: {
    metric: "mindful_minutes", unit: "min", from: { min: 1 },
  },
}

export function isSupportedType(type: string): boolean {
  return Object.prototype.hasOwnProperty.call(TYPES, type)
}

/**
 * Apple writes "2026-07-01 08:00:00 +0100". Date parsing of that form is
 * implementation-defined, so reshape it into real ISO 8601 first.
 */
export function parseAppleDate(value: string): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})\s*([+-]\d{2}):?(\d{2})?$/.exec(
    value.trim(),
  )
  if (!m) {
    const fallback = Date.parse(value)
    return Number.isNaN(fallback) ? null : fallback
  }
  const [, y, mo, d, h, mi, s, offH, offM = "00"] = m
  const iso = `${y}-${mo}-${d}T${h}:${mi}:${s}${offH}:${offM}`
  const t = Date.parse(iso)
  return Number.isNaN(t) ? null : t
}

/** One record → one canonical point, or null when unsupported/unconvertible. */
export function toCanonical(record: ParsedRecord): CanonicalPoint | null {
  const conv = TYPES[record.type]
  if (!conv) return null

  const raw = Number(record.value)
  if (!Number.isFinite(raw)) return null

  const at = parseAppleDate(record.startDate)
  if (at === null) return null

  // A category sample (mindful session) has no unit and no numeric value in
  // the way quantities do; it's handled by the caller measuring duration.
  const unitKey = record.unit ?? "min"
  const factor = conv.from[unitKey]
  if (factor === undefined) return null

  return {
    metric: conv.metric,
    value: raw * factor,
    unit: conv.unit,
    recorded_at: at,
  }
}

/**
 * Daily rollup.
 *
 * A raw export holds a record every few minutes — millions of rows, far more
 * than is worth uploading. The resolver's model is daily anyway, so points are
 * folded per (metric, local day) using the same rule the server would apply.
 * Live intraday detail comes from the app's continuous sync instead.
 */
export type DailyBucket = { metric: string; unit: string; day: string; values: number[] }

const SUM_METRICS = new Set([
  "steps", "distance", "flights_climbed", "active_energy", "basal_energy",
  "exercise_minutes", "mindful_minutes", "time_in_daylight",
  "dietary_carbohydrates", "insulin_delivery",
])
const MAX_METRICS = new Set(["vo2_max"])
const LAST_METRICS = new Set(["body_weight", "body_fat"])

export function dayKeyLocal(epochMs: number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(epochMs))
}

export function foldDaily(buckets: Map<string, DailyBucket>) {
  const out: { metric: string; value: number; unit: string; recorded_at: number }[] = []

  for (const b of buckets.values()) {
    if (b.values.length === 0) continue
    let value: number
    if (SUM_METRICS.has(b.metric)) value = b.values.reduce((a, c) => a + c, 0)
    else if (MAX_METRICS.has(b.metric)) value = Math.max(...b.values)
    else if (LAST_METRICS.has(b.metric)) value = b.values[b.values.length - 1]
    else value = b.values.reduce((a, c) => a + c, 0) / b.values.length // avg

    // midday local-ish anchor keeps the sample inside its own day whatever
    // timezone the server re-buckets it in
    out.push({
      metric: b.metric,
      value,
      unit: b.unit,
      recorded_at: Date.parse(`${b.day}T12:00:00Z`),
    })
  }

  return out
}

/** Extract complete <Record .../> elements from a text buffer. */
const RECORD_RE = /<Record\s+([^>]*?)\/?>/g
const ATTR_RE = /(\w+)="([^"]*)"/g

export function scanRecords(buffer: string): { records: ParsedRecord[]; rest: string } {
  const records: ParsedRecord[] = []
  let lastIndex = 0
  RECORD_RE.lastIndex = 0

  let m: RegExpExecArray | null
  while ((m = RECORD_RE.exec(buffer)) !== null) {
    const attrs: Record<string, string> = {}
    ATTR_RE.lastIndex = 0
    let a: RegExpExecArray | null
    while ((a = ATTR_RE.exec(m[1])) !== null) attrs[a[1]] = a[2]

    if (attrs.type && attrs.startDate && attrs.value !== undefined) {
      records.push({
        type: attrs.type,
        unit: attrs.unit ?? null,
        startDate: attrs.startDate,
        value: attrs.value,
      })
    }
    lastIndex = RECORD_RE.lastIndex
  }

  // keep the trailing partial element for the next chunk
  return { records, rest: buffer.slice(lastIndex) }
}
