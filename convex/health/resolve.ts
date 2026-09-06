import { v } from "convex/values"
import { query } from "../_generated/server"
import type { QueryCtx } from "../_generated/server"
import {
  METRICS,
  isMetricKey,
  resolveDay,
  type DaySample,
  type MetricKey,
  type ResolvedDay,
} from "./metrics"

/**
 * Source resolution.
 *
 * A user wearing a watch, a ring and carrying a phone reports the same day
 * three times. Summing everything triple-counts; averaging invents a number
 * nobody's device ever showed. Instead, for each (day, metric) we pick the
 * single highest-trust provider that actually reported, aggregate only its
 * samples, and report which provider won so the UI can say "Sleep — Oura".
 *
 * Resolution happens at read time, never at write time. Raw rows from every
 * provider stay in health_samples, so changing the trust order re-resolves
 * history rather than needing a backfill.
 */

async function priorityOverride(
  ctx: QueryCtx,
  userId: string,
  metric: string,
): Promise<string[] | null> {
  const row = await ctx.db
    .query("health_metric_sources")
    .withIndex("by_user_metric", (q) => q.eq("userId", userId).eq("metric", metric))
    .first()
  return row?.priority ?? null
}

/**
 * Resolved daily series for one metric.
 *
 * This is what every chart, briefing and AI prompt should read. Nothing
 * downstream should query health_samples directly and do its own summing —
 * that's how the double-counting bug comes back.
 */
export const dailySeries = query({
  args: {
    metric: v.string(),
    /** Inclusive YYYY-MM-DD bounds, in the user's timezone. */
    from: v.string(),
    to: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isMetricKey(args.metric)) throw new Error(`Unknown metric: ${args.metric}`)

    const metric = args.metric as MetricKey
    const userId = identity.subject
    const override = await priorityOverride(ctx, userId, metric)

    // by_user_day_metric is ordered by day, so a range scan gives the window
    const rows = await ctx.db
      .query("health_samples")
      .withIndex("by_user_day_metric", (q) =>
        q.eq("userId", userId).gte("day", args.from).lte("day", args.to),
      )
      .filter((q) => q.eq(q.field("metric"), metric))
      .collect()

    const byDay = new Map<string, DaySample[]>()
    for (const r of rows) {
      const list = byDay.get(r.day)
      const entry = { provider: r.provider, value: r.value, recorded_at: r.recorded_at }
      if (list) list.push(entry)
      else byDay.set(r.day, [entry])
    }

    const series: ResolvedDay[] = []
    for (const [day, samples] of [...byDay.entries()].sort(([a], [b]) => a.localeCompare(b))) {
      const resolved = resolveDay(metric, day, samples, override)
      if (resolved) series.push(resolved)
    }

    return {
      metric,
      unit: METRICS[metric].unit,
      aggregation: METRICS[metric].aggregation,
      series,
    }
  },
})

/**
 * Every metric, every day in a range, resolved — one query.
 *
 * The charts need ~19 metrics at once; calling dailySeries per metric would be
 * 19 round trips over the same rows. This reads the window once and resolves
 * each (day, metric) group in a single pass.
 */
export const dailyMatrix = query({
  args: {
    from: v.string(), // YYYY-MM-DD inclusive
    to: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const userId = identity.subject

    const rows = await ctx.db
      .query("health_samples")
      .withIndex("by_user_day_metric", (q) =>
        q.eq("userId", userId).gte("day", args.from).lte("day", args.to),
      )
      .collect()

    // one override lookup per metric rather than per (day, metric)
    const overrides = new Map<string, string[] | null>()
    const grouped = new Map<string, Map<string, DaySample[]>>() // day -> metric -> samples

    for (const r of rows) {
      if (!isMetricKey(r.metric)) continue
      let byMetric = grouped.get(r.day)
      if (!byMetric) {
        byMetric = new Map()
        grouped.set(r.day, byMetric)
      }
      const list = byMetric.get(r.metric)
      const entry = { provider: r.provider, value: r.value, recorded_at: r.recorded_at }
      if (list) list.push(entry)
      else byMetric.set(r.metric, [entry])
    }

    const days: {
      day: string
      metrics: Record<string, { value: number; unit: string; provider: string }>
    }[] = []

    for (const [day, byMetric] of [...grouped.entries()].sort(([a], [b]) => a.localeCompare(b))) {
      const metrics: Record<string, { value: number; unit: string; provider: string }> = {}

      for (const [metricKey, samples] of byMetric) {
        const metric = metricKey as MetricKey
        if (!overrides.has(metric)) {
          overrides.set(metric, await priorityOverride(ctx, userId, metric))
        }
        const resolved = resolveDay(metric, day, samples, overrides.get(metric))
        if (!resolved) continue
        metrics[metric] = {
          value: resolved.value,
          unit: METRICS[metric].unit,
          provider: resolved.provider,
        }
      }

      days.push({ day, metrics })
    }

    return { from: args.from, to: args.to, days }
  },
})

/**
 * One resolved value per metric for a single day — what the daily briefing
 * and the hub summary cards read.
 */
export const dailySnapshot = query({
  args: {
    day: v.string(), // YYYY-MM-DD
    metrics: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const userId = identity.subject

    const rows = await ctx.db
      .query("health_samples")
      .withIndex("by_user_day_metric", (q) => q.eq("userId", userId).eq("day", args.day))
      .collect()

    const wanted = args.metrics?.filter(isMetricKey) as MetricKey[] | undefined

    const byMetric = new Map<string, DaySample[]>()
    for (const r of rows) {
      if (!isMetricKey(r.metric)) continue
      if (wanted && !wanted.includes(r.metric as MetricKey)) continue
      const entry = { provider: r.provider, value: r.value, recorded_at: r.recorded_at }
      const list = byMetric.get(r.metric)
      if (list) list.push(entry)
      else byMetric.set(r.metric, [entry])
    }

    const out: Record<
      string,
      { value: number; unit: string; provider: string; alternatives: { provider: string; value: number }[] }
    > = {}

    for (const [metricKey, samples] of byMetric) {
      const metric = metricKey as MetricKey
      const override = await priorityOverride(ctx, userId, metric)
      const resolved = resolveDay(metric, args.day, samples, override)
      if (!resolved) continue
      out[metric] = {
        value: resolved.value,
        unit: METRICS[metric].unit,
        provider: resolved.provider,
        alternatives: resolved.alternatives,
      }
    }

    return { day: args.day, metrics: out }
  },
})
