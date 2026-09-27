import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/** Storage for bring-your-own-key AI credentials. */

/** Rows belong to whoever is asking, always. */
async function requireUser(ctx: any): Promise<string> {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) throw new Error("Not authenticated")
  return userIdOf(identity)
}

export const store = mutation({
  args: {
    provider: v.string(),
    api_key: v.string(), // already an encrypted envelope
    last4: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx)

    const existing = await ctx.db
      .query("ai_keys")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", userId).eq("provider", args.provider),
      )
      .first()

    const doc = { userId, ...args, updated_at: Date.now() }
    if (existing) {
      await ctx.db.patch(existing._id, doc)
      return existing._id
    }
    return await ctx.db.insert("ai_keys", doc)
  },
})

/**
 * Returns the caller's own encrypted envelope, for the server to decrypt when it needs to call the
 * provider on their behalf.
 */
export const envelopeFor = query({
  args: { provider: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx)
    const row = await ctx.db
      .query("ai_keys")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", userId).eq("provider", args.provider),
      )
      .first()
    return row ? { api_key: row.api_key, last4: row.last4 } : null
  },
})

export const remove = mutation({
  args: { provider: v.string() },
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx)
    const existing = await ctx.db
      .query("ai_keys")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", userId).eq("provider", args.provider),
      )
      .first()
    if (existing) await ctx.db.delete(existing._id)
  },
})

/** Which providers this user has a key for. */
export const summary = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUser(ctx)
    const rows = await ctx.db
      .query("ai_keys")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect()

    return rows.map((r) => ({
      provider: r.provider,
      last4: r.last4,
      updated_at: r.updated_at,
    }))
  },
})
