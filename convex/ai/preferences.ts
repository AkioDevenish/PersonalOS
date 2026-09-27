import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/** Which platform and model a user's insights run on. */

export const get = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.db
      .query("ai_preferences")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
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
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()

    const doc = {
      userId: userIdOf(identity),
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
