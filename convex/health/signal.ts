import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/** Carrying the messages that let two phones connect a call. */

/** Who may take part: the person who booked, or the practitioner they booked. */
async function participant(ctx: any, consultId: any, userId: string) {
  const consult = await ctx.db.get(consultId)
  if (!consult) throw new Error("No such session")
  if (consult.userId !== userId && consult.nutritionistId !== userId) {
    throw new Error("No such session")
  }
  return consult
}

export const post = mutation({
  args: {
    id: v.id("consults"),
    kind: v.string(),
    payload: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    await participant(ctx, args.id, userIdOf(identity))

    await ctx.db.insert("call_signals", {
      consultId: args.id,
      from: userIdOf(identity),
      kind: args.kind,
      payload: args.payload,
      created_at: Date.now(),
    })
    return { ok: true }
  },
})

/** Everything the other side has said since you last looked. */
export const since = query({
  args: { id: v.id("consults"), after: v.number() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    await participant(ctx, args.id, userIdOf(identity))

    const rows = await ctx.db
      .query("call_signals")
      .withIndex("by_consult_time", (q) =>
        q.eq("consultId", args.id).gt("created_at", args.after)
      )
      .collect()

    return rows
      .filter((r) => r.from !== userIdOf(identity))
      .sort((a, b) => a.created_at - b.created_at)
      .map((r) => ({ kind: r.kind, payload: r.payload, at: r.created_at }))
  },
})

/** Clears the exchange for a call. */
export const clear = mutation({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    await participant(ctx, args.id, userIdOf(identity))

    const rows = await ctx.db
      .query("call_signals")
      .withIndex("by_consult", (q) => q.eq("consultId", args.id))
      .collect()
    await Promise.all(rows.map((r) => ctx.db.delete(r._id)))
    return { cleared: rows.length }
  },
})

/** Where to find the servers that help two phones meet. */
export const iceServers = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const servers: Array<{ urls: string; username?: string; credential?: string }> = [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" },
    ]

    if (process.env.TURN_URL && process.env.TURN_USERNAME && process.env.TURN_CREDENTIAL) {
      servers.push({
        urls: process.env.TURN_URL,
        username: process.env.TURN_USERNAME,
        credential: process.env.TURN_CREDENTIAL,
      })
    }

    return { servers, relayAvailable: Boolean(process.env.TURN_URL) }
  },
})
