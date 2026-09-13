import { METRIC_KEYS, type MetricKey, type Provider } from "./metrics"

/**
 * One descriptor per provider, so the UI can render every integration the same
 * way regardless of how the data physically arrives.
 *
 * The transport difference is real — Apple Health has no server to call, so a
 * phone has to push, while Oura hands us an OAuth token and posts webhooks —
 * but that is an implementation detail. To the user both are a card with a
 * Connect button and a status. `kind` is what the connect flow branches on:
 *
 *   cloud  → redirect to the provider, come back with an external user id
 *   device → hand off to the app on that platform, which then pushes
 */

export type ProviderKind = "cloud" | "device"

export type ProviderInfo = {
  key: Provider
  label: string
  kind: ProviderKind
  /** device providers only — which app has to be installed */
  platform?: "ios" | "android"
  /** what this provider is actually good for, for the connect UI */
  highlights: string[]
  /** metrics it can supply; used to warn about gaps before connecting */
  metrics: MetricKey[]
}

const MOVEMENT: MetricKey[] = [
  "steps", "distance", "flights_climbed", "active_energy", "exercise_minutes",
]
const SLEEP: MetricKey[] = [
  "sleep_duration", "sleep_deep", "sleep_rem", "sleep_awake", "sleep_efficiency",
]
const CARDIAC: MetricKey[] = [
  "heart_rate", "resting_heart_rate", "hrv", "respiratory_rate", "spo2",
]

export const PROVIDER_INFO: Record<Provider, ProviderInfo> = {
  apple_health: {
    key: "apple_health",
    label: "Apple Health",
    kind: "device",
    platform: "ios",
    highlights: ["Everything already on your iPhone and Apple Watch"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "walking_speed", "walking_steadiness", "body_weight", "blood_glucose", "mindful_minutes", "time_in_daylight"],
  },
  health_connect: {
    key: "health_connect",
    label: "Health Connect",
    kind: "device",
    platform: "android",
    highlights: ["The Android health store — pulls from apps you already use"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "body_weight"],
  },
  samsung_health: {
    key: "samsung_health",
    label: "Samsung Health",
    kind: "device",
    platform: "android",
    highlights: ["Galaxy Watch and Samsung phones"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "body_weight"],
  },
  oura: {
    key: "oura",
    label: "Oura",
    kind: "cloud",
    highlights: ["Best-in-class sleep and recovery"],
    metrics: [...SLEEP, ...CARDIAC, "steps", "active_energy", "body_weight"],
  },
  whoop: {
    key: "whoop",
    label: "Whoop",
    kind: "cloud",
    highlights: ["Strain, recovery and continuous heart rate"],
    metrics: [...SLEEP, ...CARDIAC, "active_energy", "exercise_minutes"],
  },
  fitbit: {
    key: "fitbit",
    label: "Fitbit",
    kind: "cloud",
    highlights: ["All-day activity and sleep"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "body_weight", "body_fat"],
  },
  garmin: {
    key: "garmin",
    label: "Garmin",
    kind: "cloud",
    highlights: ["Training load and precise movement"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "vo2_max", "body_weight"],
  },
  withings: {
    key: "withings",
    label: "Withings",
    kind: "cloud",
    highlights: ["Scales and blood pressure"],
    metrics: ["body_weight", "body_fat", "heart_rate", "resting_heart_rate", "spo2", ...SLEEP],
  },
  polar: {
    key: "polar",
    label: "Polar",
    kind: "cloud",
    highlights: ["Training and cardiac detail"],
    metrics: [...MOVEMENT, ...SLEEP, ...CARDIAC, "vo2_max"],
  },
  strava: {
    key: "strava",
    label: "Strava",
    kind: "cloud",
    highlights: ["Workouts and routes"],
    metrics: ["distance", "active_energy", "exercise_minutes", "heart_rate"],
  },
  manual: {
    key: "manual",
    label: "Entered by hand",
    kind: "device",
    highlights: ["Anything you log yourself"],
    metrics: [...METRIC_KEYS],
  },
}

export function providerInfo(key: string): ProviderInfo | null {
  return (PROVIDER_INFO as Record<string, ProviderInfo>)[key] ?? null
}

/** Connectable providers, in the order the settings screen should list them. */
export const CONNECTABLE: Provider[] = [
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
]
