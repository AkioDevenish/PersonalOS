import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { mutation, query } from "../_generated/server"
import { curatedFor } from "./dishes"

/** What people in a country eat: the written list in dishes.ts, plus people's votes. */

/** Votes a dish needs before it reaches everyone's suggestions. */
export const CANON_VOTES = 3

/** Rejections that take an unvouched dish off the list. */
export const REJECTS_TO_DROP = 1

function normalise(dish: string) {
  return dish.trim().toLowerCase().replace(/\s+/g, " ")
}

/** The dishes for a country, and which of them the meal prompt may use. */
export const forCountry = query({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()

    type Entry = { dish: string; votes: number; rejects: number; written: boolean; mine: boolean }
    const blank = (dish: string): Entry => ({ dish, votes: 0, rejects: 0, written: false, mine: false })
    const byKey = new Map<string, Entry>()

    for (const dish of curatedFor(args.country)) {
      byKey.set(normalise(dish), { ...blank(dish), written: true })
    }

    for (const row of rows) {
      const entry = byKey.get(row.key) ?? blank(row.dish)
      if (row.reject) entry.rejects += 1
      else entry.votes += 1
      if (row.userId === userIdOf(identity)) entry.mine = true
      byKey.set(row.key, entry)
    }

    const all = [...byKey.entries()]
      .map(([key, e]) => ({ key, ...e }))
      .filter((d) => d.rejects < REJECTS_TO_DROP)

    return {
      threshold: CANON_VOTES,
      all: all.sort((a, b) => b.votes - a.votes || a.dish.localeCompare(b.dish)),
      // Your own vote counts for you straight away; everyone else waits for the threshold.
      canon: all
        .filter((d) => d.written || d.votes >= CANON_VOTES || (d.mine && d.votes > 0))
        .map((d) => d.dish),
    }
  },
})

/** Says a dish is not eaten in a country, or takes that back. */
export const reject = mutation({
  args: { country: v.string(), dish: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const key = normalise(args.dish)
    if (curatedFor(args.country).some((d) => normalise(d) === key)) {
      throw new Error("That dish is part of the written list for this country")
    }

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country_key", (q) => q.eq("country", args.country).eq("key", key))
      .collect()

    const votes = rows.filter((r) => !r.reject).length
    if (votes >= CANON_VOTES) {
      throw new Error("Enough people have named that dish for it to stay")
    }

    const mine = rows.find((r) => r.userId === userIdOf(identity) && r.reject)
    if (mine) {
      await ctx.db.delete(mine._id)
      return { rejected: false }
    }

    await ctx.db.insert("cuisine_dishes", {
      country: args.country,
      dish: args.dish.trim(),
      key,
      userId: userIdOf(identity),
      reject: true,
      created_at: Date.now(),
    })
    return { rejected: true }
  },
})

/** Puts a dish forward, or takes your vote back. */
export const suggest = mutation({
  args: { country: v.string(), dish: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const dish = args.dish.trim()
    if (!dish) throw new Error("A dish needs a name")
    if (dish.length > 60) throw new Error("That is longer than a dish name")

    const key = normalise(dish)
    const existing = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country_key", (q) => q.eq("country", args.country).eq("key", key))
      .collect()

    const mine = existing.find((r) => r.userId === userIdOf(identity) && !r.reject)
    if (mine) {
      await ctx.db.delete(mine._id)
      return { added: false }
    }

    await ctx.db.insert("cuisine_dishes", {
      country: args.country,
      dish,
      key,
      userId: userIdOf(identity),
      created_at: Date.now(),
    })
    return { added: true }
  },
})
