import { v } from "convex/values"
import { mutation, query } from "./_generated/server"

/**
 * The time ledger.
 *
 * The money ledger's twin, and deliberately the same shape: rows in, reading
 * derived on the way out, no idea where a row came from. A calendar feed will
 * write the same rows a person types.
 *
 * A block is a start and a number of minutes rather than a start and an end.
 * The question anyone actually answers is "how long did that take", and a
 * duration derived from two clock times is where daylight saving and midnight
 * crossings quietly produce negative hours.
 */

const MAX_CATEGORY = 40

/** A day is a long time to be doing one thing, and longer is a typo. */
const MAX_MINUTES = 24 * 60

function requireIdentity(subject: string | undefined): string {
  if (!subject) throw new Error("Not authenticated")
  return subject
}

function cleanText(raw: string, limit: number, what: string): string {
  const c = raw.trim().replace(/\s+/g, " ").slice(0, limit)
  if (!c) throw new Error(`${what} is required`)
  return c
}

/**
 * Every block that starts inside the window, with the totals worked out.
 *
 * Blocks are indexed by when they start, so one running past the end of the
 * window is included whole rather than clipped. Splitting it would mean
 * inventing a row nobody recorded; counting the whole thing is at least a
 * number a person can recognise.
 */
export const ledger = query({
  args: {
    from: v.number(),
    to: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    const userId = requireIdentity(identity?.subject)

    const rows = await ctx.db
      .query("time_blocks")
      .withIndex("by_user_start", (q) =>
        q.eq("userId", userId).gte("start", args.from).lte("start", args.to)
      )
      .collect()

    rows.sort((a, b) => b.start - a.start)

    const categories = new Map<string, { category: string; minutes: number }>()
    let total = 0
    for (const row of rows) {
      total += row.minutes
      const c = categories.get(row.category) ?? { category: row.category, minutes: 0 }
      c.minutes += row.minutes
      categories.set(row.category, c)
    }

    return {
      blocks: rows.map((r) => ({
        id: r._id,
        start: r.start,
        minutes: r.minutes,
        activity: r.activity,
        category: r.category,
        note: r.note ?? "",
        source: r.source,
      })),
      totalMinutes: total,
      byCategory: [...categories.values()].sort((a, b) => b.minutes - a.minutes),
    }
  },
})

/** Records one stretch of time. */
export const add = mutation({
  args: {
    start: v.number(),
    minutes: v.number(),
    activity: v.string(),
    category: v.string(),
    note: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    const userId = requireIdentity(identity?.subject)

    if (!Number.isInteger(args.minutes)) throw new Error("Minutes must be whole")
    if (args.minutes <= 0) throw new Error("A block needs a length")
    if (args.minutes > MAX_MINUTES) throw new Error("A block cannot be longer than a day")

    const id = await ctx.db.insert("time_blocks", {
      userId,
      start: args.start,
      minutes: args.minutes,
      activity: cleanText(args.activity, 80, "An activity"),
      category: cleanText(args.category, MAX_CATEGORY, "A category"),
      note: args.note?.trim() || undefined,
      source: "manual",
      created_at: Date.now(),
    })
    return { id }
  },
})

/** Removes one of your own blocks. */
export const remove = mutation({
  args: { id: v.id("time_blocks") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    const userId = requireIdentity(identity?.subject)

    const row = await ctx.db.get(args.id)
    if (!row || row.userId !== userId) throw new Error("No such block")

    await ctx.db.delete(args.id)
    return { removed: true }
  },
})
