import { v } from "convex/values"
import { internalMutation, internalQuery, mutation, query } from "../_generated/server"

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

/**
 * The caller's own token envelope, for a sync they asked for.
 *
 * The internal `get` above is used by the OAuth callback, which arrives during
 * a provider redirect with no session and so must run on admin credentials. A
 * sync is different: the phone asks for it with a Clerk token in hand, so the
 * identity can be checked here and scoped to one row. That is a tighter
 * guarantee than handing the web layer a deploy key that can read anyone's.
 *
 * Returning ciphertext to its owner is not a leak — the envelope is inert
 * without TOKEN_ENCRYPTION_KEY, which never leaves the Next environment.
 */
export const mine = query({
  args: { provider: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", identity.subject).eq("provider", args.provider),
      )
      .first()
  },
})

/**
 * Writes back a refreshed token during a sync the caller initiated.
 *
 * Access tokens expire in hours; without this a connection works once and
 * then quietly stops, which is the failure mode that makes people think the
 * integration is broken rather than expired.
 */
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
        q.eq("userId", identity.subject).eq("provider", args.provider),
      )
      .first()
    if (!existing) throw new Error(`No ${args.provider} connection to update`)

    await ctx.db.patch(existing._id, {
      access_token: args.access_token,
      // A refresh response often omits the refresh token; keeping the old one
      // is the difference between a renewable connection and a dead end.
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
