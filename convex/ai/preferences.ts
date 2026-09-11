import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/**
 * Which platform and model a user's insights run on.
 *
 * A model name is not a secret, so unlike the keys these values are readable
 * as themselves. Everything is still scoped to the calling identity — the
 * generator reads this with the same user token the phone sent it.
 */

export const get = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.db
      .query("ai_preferences")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .first()
  },
})

export const set = mutation({
  args: { provider: v.string(), model: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const existing = await ctx.db
      .query("ai_preferences")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .first()

    const doc = {
      userId: identity.subject,
      provider: args.provider,
      model: args.model,
      updated_at: Date.now(),
    }
    if (existing) {
      await ctx.db.patch(existing._id, doc)
      return existing._id
    }
    return await ctx.db.insert("ai_preferences", doc)
  },
})
