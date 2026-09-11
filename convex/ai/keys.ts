import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/**
 * Storage for bring-your-own-key AI credentials.
 *
 * Convex only ever holds ciphertext. The Next layer encrypts with
 * TOKEN_ENCRYPTION_KEY — which exists only in that environment — before any
 * value arrives here, so a query that returned every row would leak envelopes
 * nobody can open.
 *
 * These are authenticated public functions rather than internal ones, unlike
 * health/tokens.ts. That difference is deliberate. OAuth tokens are written
 * during a provider redirect, which carries no user session, so that path has
 * no identity to check and must run with admin credentials. A user typing
 * their own API key is always signed in, so the identity check can happen here
 * — and scoping every read and write to `identity.subject` is a stronger
 * guarantee than handing the web layer a deploy key that can touch any row.
 *
 * `last4` is stored in the clear so the app can render "which key is saved"
 * without anything having to decrypt to draw a list.
 */

/** Rows belong to whoever is asking, always. */
async function requireUser(ctx: any): Promise<string> {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) throw new Error("Not authenticated")
  return identity.subject
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
 * Returns the caller's own encrypted envelope, for the server to decrypt when
 * it needs to call the provider on their behalf. Not a leak: the envelope is
 * inert without the key, and that key never leaves the Next environment.
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

/** Which providers this user has a key for. Never includes the key itself. */
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
