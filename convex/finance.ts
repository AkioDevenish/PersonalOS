import { v } from "convex/values"
import { mutation, query } from "./_generated/server"

/**
 * The money ledger.
 *
 * Same idea as the health one: a written record rather than a dashboard. Rows
 * are movements of money, signed, in integer minor units, and the reading is
 * derived at read time rather than stored — so correcting a row corrects every
 * total that quotes it, with no recomputation step to forget to run.
 *
 * Nothing here knows where a row came from. Typed in by hand and imported from
 * a bank feed are the same shape, which is what will let a feed be added later
 * without touching this file or the screens that read it.
 */

/** Anything longer than this is a note, not a category. */
const MAX_CATEGORY = 40

function requireIdentity(subject: string | undefined): string {
  if (!subject) throw new Error("Not authenticated")
  return subject
}

function cleanCategory(raw: string): string {
  const c = raw.trim().replace(/\s+/g, " ").slice(0, MAX_CATEGORY)
  if (!c) throw new Error("A category is required")
  return c
}

/**
 * The ledger over a window, with its totals already worked out.
 *
 * Totals are grouped by currency and never summed across them. Adding dollars
 * to euros produces a number that looks authoritative and means nothing, and
 * the screen would have no way to know it was nonsense.
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
      .query("finance_entries")
      .withIndex("by_user_date", (q) =>
        q.eq("userId", userId).gte("date", args.from).lte("date", args.to)
      )
      .collect()

    // Newest first: a ledger is read from the most recent entry backwards.
    rows.sort((a, b) => b.date - a.date)

    const totals = new Map<
      string,
      { currency: string; in: number; out: number; net: number }
    >()
    const categories = new Map<string, { category: string; currency: string; minor: number }>()

    for (const row of rows) {
      const t = totals.get(row.currency) ?? {
        currency: row.currency,
        in: 0,
        out: 0,
        net: 0,
      }
      if (row.minor >= 0) t.in += row.minor
      else t.out += -row.minor
      t.net += row.minor
      totals.set(row.currency, t)

      // Only spending is worth grouping by category. Income categorised the
      // same way would sit in the same list with the opposite sign and make
      // the biggest category ambiguous.
      if (row.minor < 0) {
        const key = `${row.currency}:${row.category}`
        const c = categories.get(key) ?? {
          category: row.category,
          currency: row.currency,
          minor: 0,
        }
        c.minor += -row.minor
        categories.set(key, c)
      }
    }

    return {
      entries: rows.map((r) => ({
        id: r._id,
        date: r.date,
        minor: r.minor,
        currency: r.currency,
        category: r.category,
        note: r.note ?? "",
        source: r.source,
      })),
      totals: [...totals.values()].sort((a, b) => a.currency.localeCompare(b.currency)),
      spendByCategory: [...categories.values()].sort((a, b) => b.minor - a.minor),
    }
  },
})

/**
 * Writes one movement.
 *
 * The sign is the caller's to set, because only the caller knows whether this
 * was a wage or a bill. Zero is refused: a movement of nothing is a typing
 * mistake, and letting it through puts a row in the ledger that says nothing
 * happened.
 */
export const add = mutation({
  args: {
    date: v.number(),
    minor: v.number(),
    currency: v.string(),
    category: v.string(),
    note: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    const userId = requireIdentity(identity?.subject)

    if (!Number.isInteger(args.minor)) throw new Error("Amount must be whole minor units")
    if (args.minor === 0) throw new Error("An entry needs an amount")

    const currency = args.currency.trim().toUpperCase()
    if (currency.length !== 3) throw new Error("Currency must be a three letter code")

    const id = await ctx.db.insert("finance_entries", {
      userId,
      date: args.date,
      minor: args.minor,
      currency,
      category: cleanCategory(args.category),
      note: args.note?.trim() || undefined,
      source: "manual",
      created_at: Date.now(),
    })
    return { id }
  },
})

/** Removes one of your own rows. */
export const remove = mutation({
  args: { id: v.id("finance_entries") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    const userId = requireIdentity(identity?.subject)

    const row = await ctx.db.get(args.id)
    // Same answer for "does not exist" and "is not yours": otherwise the error
    // tells a stranger which ids are real.
    if (!row || row.userId !== userId) throw new Error("No such entry")

    await ctx.db.delete(args.id)
    return { removed: true }
  },
})
