import { userIdOf } from "./lib/me"
import { v } from "convex/values"
import { internalMutation, internalQuery, mutation } from "./_generated/server"

/** Where to reach somebody when they are not in the app. */

export const register = mutation({
  args: { token: v.string(), platform: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (args.token.length < 32 || args.token.length > 400) throw new Error("That is not a device token")

    const now = Date.now()
    const existing = await ctx.db
      .query("push_devices")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first()

    if (existing) {
      // A phone handed on to somebody else keeps its token, so the owner is rewritten rather than
      // assumed.
      await ctx.db.patch(existing._id, { userId: userIdOf(identity), updated_at: now })
      return { registered: true }
    }
    await ctx.db.insert("push_devices", {
      userId: userIdOf(identity),
      token: args.token,
      platform: args.platform,
      updated_at: now,
    })
    return { registered: true }
  },
})

/** On sign-out, so the next person to hold the phone is not sent their mail. */
export const unregister = mutation({
  args: { token: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const row = await ctx.db
      .query("push_devices")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first()
    if (row && row.userId === userIdOf(identity)) await ctx.db.delete(row._id)
    return null
  },
})

/** Internal only: tokens never leave the server to a client. */
export const forUser = internalQuery({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("push_devices")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .take(20)
    return rows.map((r) => r.token)
  },
})

/** Apple says a token is dead; stop sending to it. */
export const forget = internalMutation({
  args: { token: v.string() },
  handler: async (ctx, args) => {
    const row = await ctx.db
      .query("push_devices")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first()
    if (row) await ctx.db.delete(row._id)
    return null
  },
})
