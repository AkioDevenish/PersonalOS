import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { query } from "../_generated/server"
import type { QueryCtx } from "../_generated/server"
import {
  METRICS,
  isMetricKey,
  resolveDay,
  type DaySample,
  type MetricKey,
} from "./metrics"

/** Source resolution. */

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

/** Every metric, every day in a range, resolved — one query. */
export const dailyMatrix = query({
  args: {
    from: v.string(), // YYYY-MM-DD inclusive
    to: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const userId = userIdOf(identity)

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

