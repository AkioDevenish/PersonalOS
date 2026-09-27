import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, internalQuery, mutation, query } from "../_generated/server"

/** Storage for encrypted provider tokens. */

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
      // A refresh response often omits refresh_token; keep the existing one rather than blanking it
      // and stranding the connection.
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

/** The caller's own token envelope, for a sync they asked for. */
export const mine = query({
  args: { provider: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", userIdOf(identity)).eq("provider", args.provider),
      )
      .first()
  },
})

/** Writes back a refreshed token during a sync the caller initiated. */
export const saveMine = mutation({
  args: {
    provider: v.string(),
    access_token: v.string(),
    refresh_token: v.optional(v.string()),
    expires_at: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const existing = await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", userIdOf(identity)).eq("provider", args.provider),
      )
      .first()
    if (!existing) throw new Error(`No ${args.provider} connection to update`)

    await ctx.db.patch(existing._id, {
      access_token: args.access_token,
      // A refresh response often omits the refresh token; keeping the old one is the difference
      // between a renewable connection and a dead end.
      refresh_token: args.refresh_token ?? existing.refresh_token,
      expires_at: args.expires_at,
      updated_at: Date.now(),
    })
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
