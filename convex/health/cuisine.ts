import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query, type QueryCtx } from "../_generated/server"
import { internal } from "../_generated/api"
import { curatedFor } from "./dishes"

/** What people in a country eat: an AI list drawn from Wikipedia, plus people's votes. */

/** Votes a dish needs before it reaches everyone's suggestions. */
export const CANON_VOTES = 3

/** Rejections that take a dish off the list. */
export const REJECTS_TO_DROP = 1

/** How long a failed generation waits before it is tried again. */
const RETRY_AFTER = 24 * 60 * 60 * 1000

function normalise(dish: string) {
  return dish.trim().toLowerCase().replace(/\s+/g, " ")
}

function validCountry(country: string) {
  if (!/^[A-Z]{2}$/.test(country)) throw new Error("Not a country code")
}

/** The generated list when there is one, otherwise the hand-written list while it is made. */
async function baseList(ctx: QueryCtx, country: string) {
  const row = await ctx.db
    .query("cuisine_generated")
    .withIndex("by_country", (q) => q.eq("country", country))
    .unique()
  const done = row?.status === "done" && row.dishes.length > 0
  return {
    dishes: done ? row!.dishes : curatedFor(country),
    generated: done,
    generating: row?.status === "pending",
  }
}

/** The dishes for a country, and which of them the meal prompt may use. */
export const forCountry = query({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const base = await baseList(ctx, args.country)
    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()

    type Entry = { dish: string; votes: number; rejects: number; written: boolean; mine: boolean }
    const blank = (dish: string): Entry => ({ dish, votes: 0, rejects: 0, written: false, mine: false })
    const byKey = new Map<string, Entry>()

    for (const dish of base.dishes) byKey.set(normalise(dish), { ...blank(dish), written: true })

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
      generating: base.generating,
      generated: base.generated,
      all: all.sort((a, b) => b.votes - a.votes || a.dish.localeCompare(b.dish)),
      // Your own vote counts for you straight away; everyone else waits for the threshold.
      canon: all
        .filter((d) => d.written || d.votes >= CANON_VOTES || (d.mine && d.votes > 0))
        .map((d) => d.dish),
    }
  },
})

/** Starts generating a country's list if it has none yet. */
export const prepare = mutation({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    validCountry(args.country)
    // Without a key every attempt would fail and block retries for a day.
    if (!process.env.ANTHROPIC_API_KEY) return { started: false }

    const row = await ctx.db
      .query("cuisine_generated")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .unique()
    const now = Date.now()
    if (row?.status === "done" || row?.status === "pending") return { started: false }
    if (row?.status === "failed" && now - row.updated_at < RETRY_AFTER) return { started: false }

    if (row) await ctx.db.patch(row._id, { status: "pending", error: undefined, updated_at: now })
    else await ctx.db.insert("cuisine_generated", { country: args.country, status: "pending", dishes: [], updated_at: now })

    await ctx.scheduler.runAfter(0, internal.health.cuisineAi.generate, { country: args.country })
    return { started: true }
  },
})

/** Stores what the generator produced. An empty list counts as a failure. */
export const saveGenerated = internalMutation({
  args: {
    country: v.string(),
    dishes: v.array(v.string()),
    source: v.optional(v.string()),
    error: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const row = await ctx.db
      .query("cuisine_generated")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .unique()
    const fields = {
      status: args.dishes.length > 0 ? "done" : "failed",
      dishes: args.dishes,
      source: args.source,
      error: args.error ?? (args.dishes.length > 0 ? undefined : "No dishes found"),
      updated_at: Date.now(),
    }
    if (row) await ctx.db.patch(row._id, fields)
    else await ctx.db.insert("cuisine_generated", { country: args.country, ...fields })
  },
})

/** Says a dish is not eaten in a country, or takes that back. */
export const reject = mutation({
  args: { country: v.string(), dish: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const key = normalise(args.dish)
    const base = await baseList(ctx, args.country)
    if (!base.generated && base.dishes.some((d) => normalise(d) === key)) {
      throw new Error("That dish is part of the written list for this country")
    }

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country_key", (q) => q.eq("country", args.country).eq("key", key))
      .collect()

    if (rows.filter((r) => !r.reject).length >= CANON_VOTES) {
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

/** Puts a dish forward, or takes your vote back. One vote per person. */
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
