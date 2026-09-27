import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query } from "../_generated/server"
import { curatedFor } from "./dishes"

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

/**
 * How many people saying "not here" takes a dish off the list.
 *
 * One, because every dish this can be used on is one nobody ever vouched for:
 * a machine's guess, or something a single person typed. Somebody who lives
 * there saying it is wrong is better evidence than either, and the cost of
 * being wrong is one dish that can be added back by naming it.
 */
export const REJECTS_TO_DROP = 1

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

    type Entry = {
      dish: string
      votes: number
      rejects: number
      /** Written down in dishes.ts, and therefore trusted. */
      written: boolean
      /** Guessed by a model, and therefore not. */
      guessed: boolean
      mine: boolean
    }

    const blank = (dish: string): Entry => ({
      dish,
      votes: 0,
      rejects: 0,
      written: false,
      guessed: false,
      mine: false,
    })

    const byKey = new Map<string, Entry>()

    // The written-down list first, so it is what people see and what the
    // prompt cooks from. It lives in code rather than in rows: editing
    // dishes.ts corrects a country for everyone at once, where seeded rows
    // would have to be found and deleted.
    for (const dish of curatedFor(args.country)) {
      byKey.set(normalise(dish), { ...blank(dish), written: true })
    }

    for (const row of rows) {
      const entry = byKey.get(row.key) ?? blank(row.dish)
      if (row.reject) entry.rejects += 1
      else if (row.seeded) entry.guessed = true
      else entry.votes += 1
      if (row.userId === userIdOf(identity)) entry.mine = true
      byKey.set(row.key, entry)
    }

    const all = [...byKey.entries()]
      .map(([key, e]) => ({ key, ...e, seeded: e.written || e.guessed }))
      .filter((d) => d.rejects < REJECTS_TO_DROP)

    return {
      threshold: CANON_VOTES,
      /** Everything, for the screen that shows people what's been named. */
      all: all.sort((a, b) => b.votes - a.votes || a.dish.localeCompare(b.dish)),
      /**
       * What the prompt is allowed to cook from.
       *
       * A guessed dish is deliberately not in here. It used to be, which is
       * how bunny chow came to be offered as Trinidadian to everybody who
       * picked Trinidad: nobody had ever said it was, and nothing needed them
       * to. A model's guess is now a candidate on the screen for people to
       * confirm, and confirming it is what puts it in the prompt.
       */
      canon: all
        .filter((d) => d.written || d.votes >= CANON_VOTES || (d.mine && d.votes > 0))
        .map((d) => d.dish),
    }
  },
})


/**
 * Words that are an ingredient or a cooking method rather than a dish.
 *
 * "Curry", "Fried Chicken" and "Boiled Beans" were all written into Trinidad's
 * list. None of them is a dish anybody would name if asked what they ate — they
 * are what a model produces when it has run out of things it knows and still
 * has rows to fill.
 */
const NOT_A_DISH = new Set([
  "curry", "stew", "soup", "rice", "beans", "bread", "salad", "fish", "chicken",
  "beef", "pork", "lamb", "eggs", "fruit", "vegetables", "porridge", "noodles",
  "fried chicken", "fried fish", "boiled beans", "boiled rice", "fried rice",
  "grilled chicken", "grilled fish", "roast chicken", "mixed vegetables",
])

/**
 * Throws out a guessed list that has the shape of one that was invented.
 *
 * Angola's twenty were two dishes crossed with four proteins: caldo verde,
 * caldo verde de peixe, caldo verde de frango, and so on. That pattern is
 * recognisable without knowing anything about Angolan food — one name is the
 * whole beginning of another — so it can be refused at the door rather than
 * found later by someone who knows better.
 */
export function sift(dishes: string[]): string[] {
  const kept: string[] = []

  for (const raw of dishes) {
    const dish = raw.trim()
    if (!dish || dish.length > 60) continue

    const key = normalise(dish)
    if (NOT_A_DISH.has(key)) continue
    if (kept.some((k) => normalise(k) === key)) continue

    // A variation of something already on the list, which means the model is
    // padding rather than recalling.
    const padding = kept.some((k) => {
      const other = normalise(k)
      return key.startsWith(other + " ") || other.startsWith(key + " ")
    })
    if (padding) continue

    kept.push(dish)
  }

  // Half the list thrown away means the list was mostly invented, and the
  // remainder is not worth trusting either.
  return kept.length < dishes.length / 2 ? [] : kept
}

/**
 * Says a dish is not eaten in a country, or takes that back.
 *
 * Only usable against dishes nobody vouched for — a machine's guess, or one
 * person's suggestion. A dish enough people have named is settled, and is not
 * something one passer-by gets to remove; what is written down in dishes.ts is
 * changed by editing dishes.ts.
 */
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
      .withIndex("by_country_key", (q) =>
        q.eq("country", args.country).eq("key", key)
      )
      .collect()

    const votes = rows.filter((r) => !r.seeded && !r.reject).length
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

    const mine = existing.find(
      (r) => r.userId === userIdOf(identity) && !r.seeded && !r.reject
    )
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

    // A country with a written-down list never gets a guessed one. This is
    // the whole fix: the phone still offers to seed, and is told no.
    if (curatedFor(args.country).length > 0) return { seeded: 0 }

    const existing = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()
    // Seeded once, ever. A second seeding would let one person's model quietly
    // rewrite a country's vocabulary.
    if (existing.some((r) => r.seeded)) return { seeded: 0 }

    const seen = new Set(existing.map((r) => r.key))
    let written = 0
    for (const dish of sift(args.dishes).slice(0, 30)) {
      const key = normalise(dish)
      if (seen.has(key)) continue
      seen.add(key)
      await ctx.db.insert("cuisine_dishes", {
        country: args.country,
        dish,
        key,
        userId: userIdOf(identity),
        seeded: true,
        created_at: Date.now(),
      })
      written += 1
    }
    return { seeded: written }
  },
})

/**
 * Clears out the guessed rows for a country that has since been written down.
 *
 * Seeding happened before dishes.ts existed, and those rows outlive the change
 * — Trinidad was left holding bunny chow and fish and chips, which would go on
 * being offered to everybody because a seeded row needs no votes. Adding a
 * country to dishes.ts should therefore be followed by running this for it.
 *
 * Only guessed rows go. What a person put forward is theirs, and stays.
 */
export const dropGuessed = internalMutation({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    if (curatedFor(args.country).length === 0) {
      throw new Error(`${args.country} has no written-down list to replace them with`)
    }

    const rows = await ctx.db
      .query("cuisine_dishes")
      .withIndex("by_country", (q) => q.eq("country", args.country))
      .collect()

    let dropped = 0
    for (const row of rows) {
      if (!row.seeded) continue
      await ctx.db.delete(row._id)
      dropped += 1
    }
    return { dropped, kept: rows.length - dropped }
  },
})
