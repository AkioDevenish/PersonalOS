import { v } from "convex/values"
import { mutation, query, internalMutation } from "../_generated/server"
import type { MutationCtx } from "../_generated/server"
import { METRICS, isMetricKey, isProvider, type MetricKey } from "./metrics"

/**
 * Ingest + housekeeping for provider-agnostic health samples.
 *
 * Identity always comes from the Convex auth context (`identity.subject`, the
 * Clerk user id) for anything a client can call. Server-to-server ingest —
 * aggregator webhooks, the mobile bridge — uses the internal mutation, where
 * the caller has already verified who the payload belongs to.
 */

const sampleInput = v.object({
  metric: v.string(),
  value: v.number(),
  unit: v.string(),
  recorded_at: v.number(),
  period_end: v.optional(v.number()),
  external_id: v.optional(v.string()),
  device: v.optional(v.string()),
})

export type SampleInput = {
  metric: string
  value: number
  unit: string
  recorded_at: number
  period_end?: number
  external_id?: string
  device?: string
}

/** YYYY-MM-DD in the given IANA zone. */
export function dayKey(epochMs: number, timeZone: string): string {
  // en-CA formats as YYYY-MM-DD, which is what we want to store
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(epochMs))
}

type Rejection = { index: number; reason: string }

/**
 * Upsert keyed on (user, provider, metric, recorded_at).
 *
 * Providers re-send the same window constantly — Apple on every foreground,
 * webhooks on every partial-day update — so ingest has to be idempotent or a
 * day's steps would multiply on each sync. Re-sending a sample overwrites it
 * rather than adding a row.
 */
async function writeSamples(
  ctx: MutationCtx,
  {
    userId,
    provider,
    samples,
    timeZone,
  }: { userId: string; provider: string; samples: SampleInput[]; timeZone: string },
) {
  if (!isProvider(provider)) {
    throw new Error(`Unknown provider: ${provider}`)
  }

  let inserted = 0
  let updated = 0
  const rejected: Rejection[] = []

  for (let i = 0; i < samples.length; i++) {
    const s = samples[i]

    if (!isMetricKey(s.metric)) {
      rejected.push({ index: i, reason: `unknown metric "${s.metric}"` })
      continue
    }
    const metric = s.metric as MetricKey
    const expectedUnit = METRICS[metric].unit

    // An adapter sending the wrong unit is a silent 1000x error otherwise —
    // reject rather than guess at a conversion.
    if (s.unit !== expectedUnit) {
      rejected.push({
        index: i,
        reason: `metric "${metric}" expects ${expectedUnit}, got ${s.unit}`,
      })
      continue
    }
    if (!Number.isFinite(s.value)) {
      rejected.push({ index: i, reason: "value is not finite" })
      continue
    }
    if (!Number.isFinite(s.recorded_at)) {
      rejected.push({ index: i, reason: "recorded_at is not a timestamp" })
      continue
    }

    const existing = await ctx.db
      .query("health_samples")
      .withIndex("by_user_provider_metric_recorded", (q) =>
        q
          .eq("userId", userId)
          .eq("provider", provider)
          .eq("metric", metric)
          .eq("recorded_at", s.recorded_at),
      )
      .first()

    const doc = {
      userId,
      provider,
      metric,
      value: s.value,
      unit: s.unit,
      recorded_at: s.recorded_at,
      period_end: s.period_end,
      day: dayKey(s.recorded_at, timeZone),
      external_id: s.external_id,
      device: s.device,
      ingested_at: Date.now(),
    }

    if (existing) {
      await ctx.db.patch(existing._id, doc)
      updated++
    } else {
      await ctx.db.insert("health_samples", doc)
      inserted++
    }
  }

  return { inserted, updated, rejected }
}

/** Client-facing ingest — the phone bridge writing its own user's data. */
export const ingest = mutation({
  args: {
    provider: v.string(),
    samples: v.array(sampleInput),
    timeZone: v.optional(v.string()),
    /** Provider resume token (e.g. a serialised HKQueryAnchor). */
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const result = await writeSamples(ctx, {
      userId: identity.subject,
      provider: args.provider,
      samples: args.samples,
      timeZone: args.timeZone || "UTC",
    })

    await touchConnection(ctx, identity.subject, args.provider, args.cursor)
    return result
  },
})

/**
 * Server-to-server ingest for aggregator webhooks. The caller MUST have
 * mapped the provider's account id to a Personal OS user before calling —
 * see health_connections.by_external_user.
 */
export const ingestForUser = internalMutation({
  args: {
    userId: v.string(),
    provider: v.string(),
    samples: v.array(sampleInput),
    timeZone: v.optional(v.string()),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const result = await writeSamples(ctx, {
      userId: args.userId,
      provider: args.provider,
      samples: args.samples,
      timeZone: args.timeZone || "UTC",
    })

    await touchConnection(ctx, args.userId, args.provider, args.cursor)
    return result
  },
})

/**
 * Mark a successful sync. A device provider sitting in `pending` becomes
 * `connected` here — the first batch arriving is the only honest proof that
 * the phone side actually works.
 */
async function touchConnection(
  ctx: MutationCtx,
  userId: string,
  provider: string,
  cursor?: string,
) {
  const conn = await ctx.db
    .query("health_connections")
    .withIndex("by_user_provider", (q) => q.eq("userId", userId).eq("provider", provider))
    .first()

  if (conn) {
    await ctx.db.patch(conn._id, {
      last_sync_at: Date.now(),
      status: "connected",
      last_error: undefined,
      ...(cursor ? { sync_cursor: cursor } : {}),
    })
  }
}

/** Raw samples for one metric, all providers — for debugging and provenance UI. */
export const listRaw = query({
  args: {
    metric: v.string(),
    since: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const since = args.since ?? Date.now() - 7 * 24 * 60 * 60 * 1000

    return await ctx.db
      .query("health_samples")
      .withIndex("by_user_metric_recorded", (q) =>
        q.eq("userId", identity.subject).eq("metric", args.metric).gte("recorded_at", since),
      )
      .order("desc")
      .take(args.limit ?? 500)
  },
})
