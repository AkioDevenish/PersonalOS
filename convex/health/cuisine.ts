import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query, type QueryCtx } from "../_generated/server"
import { internal } from "../_generated/api"
import { curatedFor } from "./dishes"

/**
 * What people in a country eat: an AI list drawn from Wikipedia, plus people's votes. Saying a dish
 * is not eaten here hides it for you alone; nobody can take a dish off anyone else's list.
 */

/** Votes a dish needs before it reaches everyone's suggestions. */
export const CANON_VOTES = 3

/** How long a failed generation waits before it is tried again. */
const RETRY_AFTER = 24 * 60 * 60 * 1000

function normalise(dish: string) {
  return dish.trim().toLowerCase().replace(/\s+/g, " ")
}

function validCountry(country: string) {
  if (!/^[A-Z]{2}$/.test(country)) throw new Error("Not a country code")
}

/** Dishes one person may name or set aside in one country. Nobody eats more than this. */
const PER_PERSON = 60

/** Votes read for one country's list. */
const VOTES_READ = 8000

/** A dish name: words, not links or addresses. */
function validDish(dish: string) {
  if (!dish) throw new Error("A dish needs a name")
  if (dish.length > 60) throw new Error("That is longer than a dish name")
  if (/https?:|www\.|\.(com|net|org|io)\b|@|[<>{}\[\]\\]/i.test(dish)) {
    throw new Error("That doesn't look like a dish")
  }
}

/** Refuses a new entry from somebody who has already named a country's worth of dishes. */
async function underLimit(ctx: QueryCtx, country: string, userId: string) {
  const mine = await ctx.db
    .query("cuisine_dishes")
    .withIndex("by_country_user", (q) => q.eq("country", country).eq("userId", userId))
    .take(PER_PERSON)
  if (mine.length >= PER_PERSON) throw new Error("That's as many dishes as one person can name here")
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
    validCountry(args.country)

    const base = await baseList(ctx, args.country)
    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .take(VOTES_READ)

    type Entry = { dish: string; votes: number; hidden: boolean; written: boolean; mine: boolean }
    const blank = (dish: string): Entry => ({ dish, votes: 0, hidden: false, written: false, mine: false })
    const byKey = new Map<string, Entry>()

    for (const dish of base.dishes) byKey.set(normalise(dish), { ...blank(dish), written: true })

    for (const row of rows) {
      const entry = byKey.get(row.key) ?? blank(row.dish)
      const own = row.userId === userIdOf(identity)
      if (row.reject) {
        // Only your own rejection hides a dish, and only from you.
        if (own) entry.hidden = true
      } else {
        entry.votes += 1
        if (own) entry.mine = true
      }
      byKey.set(row.key, entry)
    }

    const all = [...byKey.entries()]
      .filter(([, e]) => !e.hidden)
      .map(([key, e]) => ({ key, dish: e.dish, votes: e.votes, written: e.written, mine: e.mine }))

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

/** Says a dish is not eaten in a country, which hides it for you, or takes that back. */
export const reject = mutation({
  args: { country: v.string(), dish: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    validCountry(args.country)
    validDish(args.dish.trim())

    const key = normalise(args.dish)
    const base = await baseList(ctx, args.country)
    if (!base.generated && base.dishes.some((d) => normalise(d) === key)) {
      throw new Error("That dish is part of the written list for this country")
    }

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country_key", (q) => q.eq("country", args.country).eq("key", key))
      .take(VOTES_READ)

    if (rows.filter((r) => !r.reject).length >= CANON_VOTES) {
      throw new Error("Enough people have named that dish for it to stay")
    }

    const mine = rows.find((r) => r.userId === userIdOf(identity) && r.reject)
    if (mine) {
      await ctx.db.delete(mine._id)
      return { rejected: false }
    }
    await underLimit(ctx, args.country, userIdOf(identity))

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

    validCountry(args.country)
    const dish = args.dish.trim()
    validDish(dish)

    const key = normalise(dish)
    const existing = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country_key", (q) => q.eq("country", args.country).eq("key", key))
      .take(VOTES_READ)

    const mine = existing.find((r) => r.userId === userIdOf(identity) && !r.reject)
    if (mine) {
      await ctx.db.delete(mine._id)
      return { added: false }
    }
    await underLimit(ctx, args.country, userIdOf(identity))

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
