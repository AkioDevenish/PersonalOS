import Constants from "expo-constants"
import type { Sample } from "../health/metrics"

/**
 * The only place the app talks to the server.
 *
 * Identity is a Clerk session token and nothing else. The old Swift bridge
 * sent an `x-personal-os-user-id` header behind a shared secret, which let any
 * device claim to be any account; that endpoint now returns 410. There is
 * deliberately no way to name a user here — whoever the token belongs to is
 * whose ledger this writes to.
 */

const extra = Constants.expoConfig?.extra as
  | { apiBaseUrl?: string; devApiBaseUrl?: string }
  | undefined

/**
 * In development, talk to the Next server on this machine.
 *
 * A phone can't resolve localhost — that would be the phone itself — so the
 * dev URL has to be the Mac's LAN address, and both must be on the same
 * Wi-Fi. Release builds always use the deployed API.
 */
const BASE_URL: string = __DEV__
  ? (extra?.devApiBaseUrl ?? extra?.apiBaseUrl ?? "http://localhost:3000")
  : (extra?.apiBaseUrl ?? "https://web-iota-eight-97.vercel.app")

/** The server caps a request at 1000 samples. */
const BATCH = 500

export type IngestResult = {
  inserted: number
  updated: number
  rejected: { index: number; reason: string }[]
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

export type GetToken = () => Promise<string | null>

async function post(path: string, body: unknown, getToken: GetToken) {
  const token = await getToken()
  if (!token) throw new ApiError(401, "Sign in to sync your health data")

  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  })

  // The API always answers JSON, including for auth failures — a fetch that
  // parses HTML here would throw something unrelated to the real problem.
  const json = await res.json().catch(() => null)

  if (!res.ok) {
    throw new ApiError(
      res.status,
      (json as { error?: string } | null)?.error ??
        (res.status === 401 ? "Your session expired — sign in again" : `Request failed (${res.status})`),
    )
  }
  return json
}

/**
 * Upload samples, batched.
 *
 * Safe to retry: ingest upserts on (user, provider, metric, recorded_at), so a
 * run that fails halfway can simply be repeated without doubling anything.
 */
export async function ingest(
  {
    provider,
    samples,
    cursor,
  }: { provider: string; samples: Sample[]; cursor?: string },
  getToken: GetToken,
): Promise<IngestResult> {
  const total: IngestResult = { inserted: 0, updated: 0, rejected: [] }
  if (samples.length === 0) return total

  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone

  for (let i = 0; i < samples.length; i += BATCH) {
    const batch = samples.slice(i, i + BATCH)
    const isLast = i + BATCH >= samples.length

    const result = (await post(
      "/api/health/ingest",
      {
        provider,
        samples: batch,
        timeZone,
        // only advance the resume point once everything has landed
        cursor: isLast ? cursor : undefined,
      },
      getToken,
    )) as IngestResult

    total.inserted += result?.inserted ?? 0
    total.updated += result?.updated ?? 0
    if (result?.rejected?.length) total.rejected.push(...result.rejected)
  }

  return total
}

export const apiBaseUrl = BASE_URL
