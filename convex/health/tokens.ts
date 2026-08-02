import { v } from "convex/values"
import { internalMutation, internalQuery } from "../_generated/server"

/**
 * Storage for encrypted provider tokens.
 *
 * Every function here is internal — there is no public query that returns a
 * token, encrypted or otherwise. Values arrive already encrypted by the Next
 * layer; Convex is a place to put opaque strings, not a party to the secret.
 */

export const store = internalMutation({
  args: {
    userId: v.string(),
    provider: v.string(),
    access_token: v.string(),
    refresh_token: v.optional(v.string()),
    expires_at: v.optional(v.number()),
    scopes: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()

    const doc = { ...args, updated_at: Date.now() }

    if (existing) {
      // A refresh response often omits refresh_token; keep the existing one
      // rather than blanking it and stranding the connection.
      await ctx.db.patch(existing._id, {
        ...doc,
        refresh_token: args.refresh_token ?? existing.refresh_token,
      })
      return existing._id
    }
    return await ctx.db.insert("health_oauth_tokens", doc)
  },
})

export const get = internalQuery({
  args: { userId: v.string(), provider: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()
  },
})

/** Called on disconnect — revoking access should not leave the key behind. */
export const remove = internalMutation({
  args: { userId: v.string(), provider: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()
    if (existing) await ctx.db.delete(existing._id)
  },
})
