/**
 * Canonical health vocabulary.
 *
 * Every provider names and measures things differently — Fitbit reports
 * distance in km, Apple in metres, Oura reports sleep as one nightly block
 * while Apple emits a row per stage. Adapters translate into the metric keys
 * and units below, and nothing downstream ever sees a provider's own naming.
 *
 * Lives under convex/ so both the Convex functions and the Next app can
 * import it without duplicating the table.
 */

/** Units are canonical. An adapter that can't convert should drop the sample. */
export const METRICS = {
  steps: { unit: "count", aggregation: "sum" },
  distance: { unit: "m", aggregation: "sum" },
  flights_climbed: { unit: "count", aggregation: "sum" },
  active_energy: { unit: "kcal", aggregation: "sum" },
  basal_energy: { unit: "kcal", aggregation: "sum" },
  exercise_minutes: { unit: "min", aggregation: "sum" },

  sleep_duration: { unit: "min", aggregation: "sum" },
  sleep_deep: { unit: "min", aggregation: "sum" },
  sleep_rem: { unit: "min", aggregation: "sum" },
  sleep_awake: { unit: "min", aggregation: "sum" },
  sleep_efficiency: { unit: "pct", aggregation: "avg" },

  heart_rate: { unit: "bpm", aggregation: "avg" },
  resting_heart_rate: { unit: "bpm", aggregation: "avg" },
  hrv: { unit: "ms", aggregation: "avg" },
  respiratory_rate: { unit: "brpm", aggregation: "avg" },
  spo2: { unit: "pct", aggregation: "avg" },
  vo2_max: { unit: "ml/kg/min", aggregation: "max" },

  body_weight: { unit: "kg", aggregation: "last" },
  body_fat: { unit: "pct", aggregation: "last" },

  blood_glucose: { unit: "mg/dL", aggregation: "avg" },
  dietary_carbohydrates: { unit: "g", aggregation: "sum" },
  insulin_delivery: { unit: "IU", aggregation: "sum" },

  walking_speed: { unit: "m/s", aggregation: "avg" },
  walking_steadiness: { unit: "pct", aggregation: "avg" },
  mindful_minutes: { unit: "min", aggregation: "sum" },
  time_in_daylight: { unit: "min", aggregation: "sum" },

  // gait detail — Apple Health / Health Connect supply these; without them
  // the iOS bridge would have samples silently rejected as unknown metrics
  walking_asymmetry: { unit: "pct", aggregation: "avg" },
  walking_step_length: { unit: "m", aggregation: "avg" },
  walking_double_support: { unit: "pct", aggregation: "avg" },
  stair_ascent_speed: { unit: "m/s", aggregation: "avg" },
  headphone_audio_exposure: { unit: "dB", aggregation: "avg" },
} as const

export type MetricKey = keyof typeof METRICS
export type Aggregation = (typeof METRICS)[MetricKey]["aggregation"]

export const METRIC_KEYS = Object.keys(METRICS) as MetricKey[]

export function isMetricKey(value: string): value is MetricKey {
  return Object.prototype.hasOwnProperty.call(METRICS, value)
}

/** Providers we can ingest from. `manual` is user-entered. */
export const PROVIDERS = [
  "apple_health",
  "health_connect",
  "samsung_health",
  "oura",
  "whoop",
  "fitbit",
  "garmin",
  "withings",
  "polar",
  "strava",
  "manual",
] as const

export type Provider = (typeof PROVIDERS)[number]

export function isProvider(value: string): value is Provider {
  return (PROVIDERS as readonly string[]).includes(value)
}

/**
 * Default trust order per metric, most trusted first.
 *
 * This is what stops a user with a phone, a ring and a watch from being shown
 * three different step counts added together. For each day and metric we take
 * the highest-ranked provider that actually reported, and ignore the rest.
 *
 * The ordering reflects what the hardware is genuinely good at rather than
 * brand preference: dedicated sleep hardware wins sleep, chest/wrist optical
 * sensors win cardiac, a worn watch beats a pocketed phone for movement.
 * Users can override per metric — see `metric_sources` in the schema.
 */
const MOVEMENT_ORDER: Provider[] = [
  "garmin", "whoop", "fitbit", "apple_health", "samsung_health", "health_connect", "polar", "strava", "manual",
]

const SLEEP_ORDER: Provider[] = [
  "oura", "whoop", "garmin", "fitbit", "apple_health", "samsung_health", "health_connect", "polar", "manual",
]

const CARDIAC_ORDER: Provider[] = [
  "whoop", "oura", "garmin", "polar", "fitbit", "apple_health", "samsung_health", "health_connect", "manual",
]

const BODY_ORDER: Provider[] = [
  "withings", "garmin", "fitbit", "apple_health", "samsung_health", "health_connect", "manual",
]

/** Anything not named here falls back to GENERAL_ORDER. */
const GENERAL_ORDER: Provider[] = [
  "apple_health", "health_connect", "samsung_health", "garmin", "oura", "whoop", "fitbit", "withings", "polar", "strava", "manual",
]

const PRIORITY_BY_METRIC: Partial<Record<MetricKey, Provider[]>> = {
  steps: MOVEMENT_ORDER,
  distance: MOVEMENT_ORDER,
  flights_climbed: MOVEMENT_ORDER,
  active_energy: MOVEMENT_ORDER,
  basal_energy: MOVEMENT_ORDER,
  exercise_minutes: MOVEMENT_ORDER,

  sleep_duration: SLEEP_ORDER,
  sleep_deep: SLEEP_ORDER,
  sleep_rem: SLEEP_ORDER,
  sleep_awake: SLEEP_ORDER,
  sleep_efficiency: SLEEP_ORDER,

  heart_rate: CARDIAC_ORDER,
  resting_heart_rate: CARDIAC_ORDER,
  hrv: CARDIAC_ORDER,
  respiratory_rate: CARDIAC_ORDER,
  spo2: CARDIAC_ORDER,
  vo2_max: CARDIAC_ORDER,

  body_weight: BODY_ORDER,
  body_fat: BODY_ORDER,
}

export function defaultPriority(metric: MetricKey): Provider[] {
  return PRIORITY_BY_METRIC[metric] ?? GENERAL_ORDER
}

/**
 * Rank a provider for a metric. Lower wins. Providers absent from the list
 * sort last rather than being discarded, so a newly added provider still
 * shows data before anyone has tuned its priority.
 */
export function providerRank(
  metric: MetricKey,
  provider: string,
  override?: string[] | null,
): number {
  const order = override && override.length > 0 ? override : defaultPriority(metric)
  const i = order.indexOf(provider as Provider)
  return i === -1 ? Number.MAX_SAFE_INTEGER : i
}

export type DaySample = { provider: string; value: number; recorded_at: number }

export type ResolvedDay = {
  day: string
  value: number
  provider: string
  /** Providers that also had data but lost — surfaced as "also from…" in UI. */
  alternatives: { provider: string; value: number }[]
}

/**
 * The dedup rule, kept pure and free of Convex imports so it can be unit
 * tested on its own.
 *
 * Group one day's samples by provider, aggregate each provider independently,
 * then let the trust order pick a single winner. Never sums across providers —
 * that is exactly the triple-counting this exists to prevent.
 */
export function resolveDay(
  metric: MetricKey,
  day: string,
  samples: DaySample[],
  override?: string[] | null,
): ResolvedDay | null {
  if (samples.length === 0) return null

  const byProvider = new Map<string, DaySample[]>()
  for (const s of samples) {
    const list = byProvider.get(s.provider)
    if (list) list.push(s)
    else byProvider.set(s.provider, [s])
  }

  const perProvider: { provider: string; value: number; rank: number }[] = []
  for (const [provider, rows] of byProvider) {
    // "last" aggregation needs chronological order
    rows.sort((a, b) => a.recorded_at - b.recorded_at)
    const value = aggregate(metric, rows.map((r) => r.value))
    if (value === null) continue
    perProvider.push({ provider, value, rank: providerRank(metric, provider, override) })
  }

  if (perProvider.length === 0) return null

  // ties broken by provider name so the choice is stable between reads
  perProvider.sort((a, b) => a.rank - b.rank || a.provider.localeCompare(b.provider))
  const [winner, ...rest] = perProvider

  return {
    day,
    value: winner.value,
    provider: winner.provider,
    alternatives: rest.map(({ provider, value }) => ({ provider, value })),
  }
}

/** Combine same-provider samples for one day according to the metric's rule. */
export function aggregate(metric: MetricKey, values: number[]): number | null {
  if (values.length === 0) return null
  switch (METRICS[metric].aggregation) {
    case "sum":
      return values.reduce((a, b) => a + b, 0)
    case "avg":
      return values.reduce((a, b) => a + b, 0) / values.length
    case "max":
      return Math.max(...values)
    case "last":
      // callers pass values already ordered oldest → newest
      return values[values.length - 1]
  }
}
