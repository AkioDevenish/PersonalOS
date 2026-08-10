import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/**
 * What people in a country actually eat.
 *
 * A model asked to name everyday food in a country it knows little about will
 * produce something plausible-shaped rather than something real — and the
 * smaller the model, the more confidently. Naming the country in the prompt
 * was never going to fix that: recalling dishes from nothing is the hard task.
 * Choosing from a list is the easy one.
 *
 * So the list comes from people. Anyone can put a dish forward, one vote each,
 * and once enough people have named the same thing it becomes part of what the
 * model is told to choose from for that country. Ten people saying "doubles"
 * is a better authority on Trinidadian breakfast than any model, and it is the
 * kind of thing only the people eating it can tell you.
 */

/**
 * How many people it takes for a dish to become canon for a country.
 *
 * Ten is the right number for an app with users; three is the right number for
 * an app with a handful, where a threshold of ten means the list stays empty
 * forever and the feature never does anything. One constant, moved up as the
 * numbers justify it.
 */
export const CANON_VOTES = 3

/** Lowercased and squeezed, so "Doubles", "doubles " and "DOUBLES" are one dish. */
function normalise(dish: string) {
  return dish.trim().toLowerCase().replace(/\s+/g, " ")
}

/**
 * The dishes for a country: those enough people have vouched for, plus
 * whatever the caller themselves added.
 *
 * Your own suggestion counts for you immediately. Waiting for two strangers to
 * agree before the app will cook you something you told it you eat would be
 * absurd — the threshold is about what everyone else's prompt gets, not about
 * whether you are trusted about your own dinner.
 */
export const forCountry = query({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()

    const byKey = new Map<
      string,
      { dish: string; votes: number; seeded: boolean; mine: boolean }
    >()

    for (const row of rows) {
      const entry = byKey.get(row.key) ?? {
        dish: row.dish,
        votes: 0,
        seeded: false,
        mine: false,
      }
      if (row.seeded) entry.seeded = true
      else entry.votes += 1
      if (row.userId === identity.subject) entry.mine = true
      byKey.set(row.key, entry)
    }

    const all = [...byKey.entries()].map(([key, e]) => ({ key, ...e }))

    return {
      threshold: CANON_VOTES,
      /** Everything, for the screen that shows people what's been named. */
      all: all.sort((a, b) => b.votes - a.votes || a.dish.localeCompare(b.dish)),
      /** What the prompt is allowed to cook from. */
      canon: all
        .filter((d) => d.votes >= CANON_VOTES || d.seeded || d.mine)
        .map((d) => d.dish),
    }
  },
})

/**
 * Put a dish forward, or take your vote back if you already had.
 *
 * Idempotent per person: the row is the vote, so voting twice is a no-op and
 * un-voting is a delete. Nobody can run the count up on their own.
 */
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
      .withIndex("by_country_key", (q) =>
        q.eq("country", args.country).eq("key", key)
      )
      .collect()

    const mine = existing.find((r) => r.userId === identity.subject && !r.seeded)
    if (mine) {
      await ctx.db.delete(mine._id)
      return { added: false }
    }

    await ctx.db.insert("cuisine_dishes", {
      country: args.country,
      dish,
      key,
      userId: identity.subject,
      created_at: Date.now(),
    })
    return { added: true }
  },
})

/**
 * The starter list, written once per country by whatever model the caller has.
 *
 * Seeded rows carry no vote — they are a first guess, there so the very first
 * person to pick a country is not handed an empty vocabulary. People's own
 * suggestions outrank them by simply existing, and a seeded dish nobody ever
 * eats stays at zero votes forever, which is the correct fate for it.
 */
export const seed = mutation({
  args: { country: v.string(), dishes: v.array(v.string()) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const existing = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()
    // Seeded once, ever. A second seeding would let one person's model quietly
    // rewrite a country's vocabulary.
    if (existing.some((r) => r.seeded)) return { seeded: 0 }

    const seen = new Set(existing.map((r) => r.key))
    let written = 0
    for (const raw of args.dishes.slice(0, 30)) {
      const dish = raw.trim()
      if (!dish || dish.length > 60) continue
      const key = normalise(dish)
      if (seen.has(key)) continue
      seen.add(key)
      await ctx.db.insert("cuisine_dishes", {
        country: args.country,
        dish,
        key,
        userId: identity.subject,
        seeded: true,
        created_at: Date.now(),
      })
      written += 1
    }
    return { seeded: written }
  },
})
