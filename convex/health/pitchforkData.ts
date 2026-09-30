import { v } from "convex/values"
import { internalMutation, internalQuery } from "../_generated/server"
import { METRICS, isMetricKey, resolveDay, type DaySample } from "./metrics"

/** What Pitchfork's tools read, and how often one person may ask it something. */

/** Messages one person can send Pitchfork in a day. Each one is a paid model call. */
export const DAILY_LIMIT = 150

/** The furthest back Pitchfork looks in one go. */
export const MAX_DAYS = 90

/** Counts one message against today's allowance, or refuses when it is used up. */
export const take = internalMutation({
  args: { userId: v.string(), day: v.string() },
  returns: v.object({ ok: v.boolean(), left: v.number() }),
  handler: async (ctx, args) => {
    const row = await ctx.db
      .query("pitchfork_usage")
      .withIndex("by_userId_and_day", (q) => q.eq("userId", args.userId).eq("day", args.day))
      .unique()
    const used = row?.count ?? 0
    if (used >= DAILY_LIMIT) return { ok: false, left: 0 }
    if (row) await ctx.db.patch(row._id, { count: used + 1 })
    else await ctx.db.insert("pitchfork_usage", { userId: args.userId, day: args.day, count: 1 })
    return { ok: true, left: DAILY_LIMIT - used - 1 }
  },
})

/** One metric, one value per day, oldest first, with the same provider rules the app uses. */
export const history = internalQuery({
  args: { userId: v.string(), metric: v.string(), days: v.number(), now: v.number() },
  returns: v.object({
    metric: v.string(),
    unit: v.string(),
    days: v.array(v.object({ day: v.string(), value: v.number() })),
  }),
  handler: async (ctx, args) => {
    if (!isMetricKey(args.metric)) throw new Error(`Unknown metric: ${args.metric}`)
    const metric = args.metric
    const days = Math.min(MAX_DAYS, Math.max(1, Math.round(args.days)))
    const since = args.now - days * 24 * 60 * 60 * 1000

    const rows = await ctx.db
      .query("health_samples")
      .withIndex("by_user_metric_recorded", (q) =>
        q.eq("userId", args.userId).eq("metric", metric).gte("recorded_at", since),
      )
      .take(10_000)

    const override = await ctx.db
      .query("health_metric_sources")
      .withIndex("by_user_metric", (q) => q.eq("userId", args.userId).eq("metric", metric))
      .first()

    const byDay = new Map<string, DaySample[]>()
    for (const r of rows) {
      const list = byDay.get(r.day)
      const sample = { provider: r.provider, value: r.value, recorded_at: r.recorded_at }
      if (list) list.push(sample)
      else byDay.set(r.day, [sample])
    }

    const resolved = [...byDay.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([day, samples]) => resolveDay(metric, day, samples, override?.priority))
      .filter((d) => d !== null)
      .map((d) => ({ day: d.day, value: Math.round(d.value * 10) / 10 }))

    return { metric, unit: METRICS[metric].unit, days: resolved }
  },
})
