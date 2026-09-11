import { oauthProvider, credentialsFor, type OAuthProvider } from "./oauth-providers"

/**
 * Pulling actual measurements out of Oura, Whoop and Fitbit.
 *
 * The OAuth layer only ever established *who* — it linked an account and
 * stored a token, and nothing in the codebase then went and fetched anything.
 * This is that missing half.
 *
 * Each provider returns its own shape in its own units: Oura reports sleep in
 * seconds, Fitbit in minutes, Whoop in milliseconds; Fitbit measures distance
 * in kilometres while the canonical unit is metres; Whoop reports efficiency
 * and recovery as fractions where the registry wants percent. Every adapter
 * converts on the way out, so nothing downstream ever learns a vendor's
 * naming — that is the whole point of the canonical registry in
 * convex/health/metrics.ts.
 *
 * A sample whose unit cannot be converted is dropped rather than guessed. A
 * wrong number in a health ledger is worse than a missing one.
 */

export type Sample = {
  metric: string
  value: number
  unit: string
  recorded_at: number
  source_device?: string
}

export type PullResult = {
  samples: Sample[]
  /** ISO date of the newest day seen, stored as the resume point. */
  cursor?: string
}

/** Midnight UTC for a YYYY-MM-DD day, the timestamp daily figures anchor to. */
function dayStamp(day: string): number {
  return Date.parse(`${day}T00:00:00Z`)
}

function iso(d: Date): string {
  return d.toISOString().slice(0, 10)
}

/** Only finite, non-negative numbers reach the ledger. */
function push(out: Sample[], metric: string, value: unknown, unit: string, at: number, device?: string) {
  const n = typeof value === "number" ? value : Number(value)
  if (!Number.isFinite(n) || n < 0) return
  out.push({ metric, value: n, unit, recorded_at: at, source_device: device })
}

async function getJson(url: string, token: string): Promise<any> {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } })
  if (!res.ok) {
    const body = await res.text().catch(() => "")
    throw new PullError(
      res.status === 401
        ? "That connection has expired. Reconnect the account."
        : `Provider returned HTTP ${res.status}: ${body.slice(0, 200)}`,
      res.status === 401 ? 401 : 502,
    )
  }
  return res.json()
}

export class PullError extends Error {
  constructor(message: string, readonly status = 502) {
    super(message)
    this.name = "PullError"
  }
}

// MARK: - Token refresh

export type RefreshedToken = {
  access_token: string
  refresh_token?: string
  expires_at?: number
}

/**
 * Exchanges a refresh token for a new access token.
 *
 * Returns null when the connection has no refresh token — Oura's older grants
 * and any provider where `offline` scope wasn't requested — so the caller can
 * try the existing access token rather than failing outright.
 */
export async function refreshAccessToken(
  providerKey: string,
  refreshToken: string | undefined,
): Promise<RefreshedToken | null> {
  if (!refreshToken) return null
  const provider = oauthProvider(providerKey)
  if (!provider) throw new PullError(`Unknown provider "${providerKey}"`, 400)
  const creds = credentialsFor(provider)
  if (!creds) throw new PullError(`${provider.label} is not configured on this server.`, 503)

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  })
  const headers: Record<string, string> = {
    "Content-Type": "application/x-www-form-urlencoded",
  }
  if (provider.tokenAuth === "basic") {
    const basic = Buffer.from(`${creds.clientId}:${creds.clientSecret}`).toString("base64")
    headers.Authorization = `Basic ${basic}`
  } else {
    body.set("client_id", creds.clientId)
    body.set("client_secret", creds.clientSecret)
  }

  const res = await fetch(provider.tokenUrl, { method: "POST", headers, body })
  if (!res.ok) {
    throw new PullError(
      `Couldn't renew the ${provider.label} connection — reconnect the account.`,
      401,
    )
  }
  const json = await res.json()
  return {
    access_token: json.access_token,
    refresh_token: json.refresh_token,
    expires_at:
      typeof json.expires_in === "number" ? Date.now() + json.expires_in * 1000 : undefined,
  }
}

// MARK: - Oura

async function pullOura(token: string, since: string, until: string): Promise<PullResult> {
  const out: Sample[] = []
  const range = `start_date=${since}&end_date=${until}`
  const base = "https://api.ouraring.com/v2/usercollection"

  const [sleep, activity, readiness] = await Promise.all([
    getJson(`${base}/daily_sleep?${range}`, token).catch(() => null),
    getJson(`${base}/daily_activity?${range}`, token).catch(() => null),
    getJson(`${base}/sleep?${range}`, token).catch(() => null),
  ])

  for (const d of sleep?.data ?? []) {
    const at = dayStamp(d.day)
    push(out, "sleep_efficiency", d.contributors?.efficiency, "pct", at, "oura")
  }

  for (const d of activity?.data ?? []) {
    const at = dayStamp(d.day)
    push(out, "steps", d.steps, "count", at, "oura")
    push(out, "active_energy", d.active_calories, "kcal", at, "oura")
    // Oura reports total calories; basal is the part that isn't activity.
    if (typeof d.total_calories === "number" && typeof d.active_calories === "number") {
      push(out, "basal_energy", d.total_calories - d.active_calories, "kcal", at, "oura")
    }
    push(out, "distance", d.equivalent_walking_distance, "m", at, "oura")
  }

  // Detailed sleep sessions carry the durations, in seconds.
  for (const d of readiness?.data ?? []) {
    const at = dayStamp(d.day)
    push(out, "sleep_duration", secondsToMin(d.total_sleep_duration), "min", at, "oura")
    push(out, "sleep_deep", secondsToMin(d.deep_sleep_duration), "min", at, "oura")
    push(out, "sleep_rem", secondsToMin(d.rem_sleep_duration), "min", at, "oura")
    push(out, "sleep_awake", secondsToMin(d.awake_time), "min", at, "oura")
    push(out, "resting_heart_rate", d.lowest_heart_rate, "bpm", at, "oura")
    push(out, "hrv", d.average_hrv, "ms", at, "oura")
    push(out, "respiratory_rate", d.average_breath, "brpm", at, "oura")
  }

  return { samples: out, cursor: until }
}

function secondsToMin(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(v)
  return Number.isFinite(n) ? n / 60 : undefined
}

// MARK: - Fitbit

async function pullFitbit(token: string, since: string, until: string): Promise<PullResult> {
  const out: Sample[] = []
  const base = "https://api.fitbit.com/1"

  const [steps, calories, distance, resting, sleep] = await Promise.all([
    getJson(`${base}/user/-/activities/steps/date/${since}/${until}.json`, token).catch(() => null),
    getJson(`${base}/user/-/activities/calories/date/${since}/${until}.json`, token).catch(() => null),
    getJson(`${base}/user/-/activities/distance/date/${since}/${until}.json`, token).catch(() => null),
    getJson(`${base}/user/-/activities/heart/date/${since}/${until}.json`, token).catch(() => null),
    getJson(`${base}.2/user/-/sleep/date/${since}/${until}.json`, token).catch(() => null),
  ])

  for (const d of steps?.["activities-steps"] ?? []) {
    push(out, "steps", d.value, "count", dayStamp(d.dateTime), "fitbit")
  }
  for (const d of calories?.["activities-calories"] ?? []) {
    push(out, "active_energy", d.value, "kcal", dayStamp(d.dateTime), "fitbit")
  }
  for (const d of distance?.["activities-distance"] ?? []) {
    // Fitbit reports kilometres; the canonical unit is metres.
    const km = Number(d.value)
    if (Number.isFinite(km)) {
      push(out, "distance", km * 1000, "m", dayStamp(d.dateTime), "fitbit")
    }
  }
  for (const d of resting?.["activities-heart"] ?? []) {
    push(out, "resting_heart_rate", d.value?.restingHeartRate, "bpm", dayStamp(d.dateTime), "fitbit")
  }
  for (const s of sleep?.sleep ?? []) {
    const at = dayStamp(String(s.dateOfSleep))
    // Fitbit gives milliseconds for total time, minutes for stages.
    push(out, "sleep_duration", msToMin(s.duration), "min", at, "fitbit")
    push(out, "sleep_efficiency", s.efficiency, "pct", at, "fitbit")
    const stages = s.levels?.summary
    push(out, "sleep_deep", stages?.deep?.minutes, "min", at, "fitbit")
    push(out, "sleep_rem", stages?.rem?.minutes, "min", at, "fitbit")
    push(out, "sleep_awake", stages?.wake?.minutes, "min", at, "fitbit")
  }

  return { samples: out, cursor: until }
}

function msToMin(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(v)
  return Number.isFinite(n) ? n / 60000 : undefined
}

// MARK: - Whoop

async function pullWhoop(token: string, since: string, until: string): Promise<PullResult> {
  const out: Sample[] = []
  const base = "https://api.prod.whoop.com/developer/v1"
  const range = `start=${since}T00:00:00.000Z&end=${until}T23:59:59.999Z`

  const [sleep, recovery, cycles] = await Promise.all([
    getJson(`${base}/activity/sleep?${range}&limit=25`, token).catch(() => null),
    getJson(`${base}/recovery?${range}&limit=25`, token).catch(() => null),
    getJson(`${base}/cycle?${range}&limit=25`, token).catch(() => null),
  ])

  for (const s of sleep?.records ?? []) {
    const at = dayStamp(String(s.end ?? s.start).slice(0, 10))
    const score = s.score
    push(out, "sleep_duration", msToMin(score?.stage_summary?.total_in_bed_time_milli), "min", at, "whoop")
    push(out, "sleep_deep", msToMin(score?.stage_summary?.total_slow_wave_sleep_time_milli), "min", at, "whoop")
    push(out, "sleep_rem", msToMin(score?.stage_summary?.total_rem_sleep_time_milli), "min", at, "whoop")
    push(out, "sleep_awake", msToMin(score?.stage_summary?.total_awake_time_milli), "min", at, "whoop")
    push(out, "sleep_efficiency", score?.sleep_efficiency_percentage, "pct", at, "whoop")
    push(out, "respiratory_rate", score?.respiratory_rate, "brpm", at, "whoop")
  }

  for (const r of recovery?.records ?? []) {
    const at = dayStamp(String(r.created_at).slice(0, 10))
    push(out, "resting_heart_rate", r.score?.resting_heart_rate, "bpm", at, "whoop")
    push(out, "hrv", msToHrvMs(r.score?.hrv_rmssd_milli), "ms", at, "whoop")
    push(out, "spo2", r.score?.spo2_percentage, "pct", at, "whoop")
  }

  for (const c of cycles?.records ?? []) {
    const at = dayStamp(String(c.start).slice(0, 10))
    push(out, "active_energy", kilojoulesToKcal(c.score?.kilojoule), "kcal", at, "whoop")
    push(out, "heart_rate", c.score?.average_heart_rate, "bpm", at, "whoop")
  }

  return { samples: out, cursor: until }
}

/** Whoop's field is already milliseconds despite the name suggesting otherwise. */
function msToHrvMs(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(v)
  return Number.isFinite(n) ? n : undefined
}

function kilojoulesToKcal(v: unknown): number | undefined {
  const n = typeof v === "number" ? v : Number(v)
  return Number.isFinite(n) ? n / 4.184 : undefined
}

// MARK: - Dispatch

const PULLERS: Record<string, (token: string, since: string, until: string) => Promise<PullResult>> = {
  oura: pullOura,
  fitbit: pullFitbit,
  whoop: pullWhoop,
}

export function canPull(provider: string): boolean {
  return provider in PULLERS
}

/**
 * Fetches a window of days from one provider.
 *
 * `since` defaults to a week back rather than the beginning of time: providers
 * rate limit hard, and the ingest is idempotent on
 * (user, provider, metric, recorded_at), so re-fetching an overlapping window
 * costs nothing and repairs any day that failed last time.
 */
export async function pull(
  provider: string,
  token: string,
  opts: { since?: string; days?: number } = {},
): Promise<PullResult> {
  const puller = PULLERS[provider]
  if (!puller) throw new PullError(`Can't pull from "${provider}" yet.`, 400)

  const until = new Date()
  const start = opts.since
    ? new Date(opts.since)
    : new Date(until.getTime() - (opts.days ?? 7) * 86_400_000)

  return puller(token, iso(start), iso(until))
}

export { iso as isoDay }
