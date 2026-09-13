import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/**
 * Carrying the messages that let two phones connect a call.
 *
 * WebRTC connects devices directly, but it cannot introduce them. Each side
 * has to describe what codecs it speaks and which addresses it can be reached
 * on, and something has to pass those descriptions across. This is that
 * something, and it is the whole of what a signalling server does.
 *
 * Polled rather than pushed, because the phone reaches Convex over HTTP. That
 * is fine here in a way it would not be for the media itself: connecting a
 * call takes a dozen messages over a few seconds, and a second of delay in
 * that exchange is a second before the video starts, not a stutter during it.
 */

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
    await participant(ctx, args.id, identity.subject)

    await ctx.db.insert("call_signals", {
      consultId: args.id,
      from: identity.subject,
      kind: args.kind,
      payload: args.payload,
      created_at: Date.now(),
    })
    return { ok: true }
  },
})

/**
 * Everything the other side has said since you last looked.
 *
 * Filtered to the other participant: a phone reading back its own offer would
 * try to answer itself, which is a genuinely confusing failure to debug.
 */
export const since = query({
  args: { id: v.id("consults"), after: v.number() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    await participant(ctx, args.id, identity.subject)

    const rows = await ctx.db
      .query("call_signals")
      .withIndex("by_consult_time", (q) =>
        q.eq("consultId", args.id).gt("created_at", args.after)
      )
      .collect()

    return rows
      .filter((r) => r.from !== identity.subject)
      .sort((a, b) => a.created_at - b.created_at)
      .map((r) => ({ kind: r.kind, payload: r.payload, at: r.created_at }))
  },
})

/**
 * Clears the exchange for a call.
 *
 * Called when hanging up and before dialling again. Stale candidates from a
 * previous attempt are worse than none: the stack will spend time trying to
 * reach addresses that stopped being valid when the network changed.
 */
export const clear = mutation({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    await participant(ctx, args.id, identity.subject)

    const rows = await ctx.db
      .query("call_signals")
      .withIndex("by_consult", (q) => q.eq("consultId", args.id))
      .collect()
    await Promise.all(rows.map((r) => ctx.db.delete(r._id)))
    return { cleared: rows.length }
  },
})

/**
 * Where to find the servers that help two phones meet.
 *
 * STUN tells a phone its own public address, and Google run one for anybody
 * to use. TURN relays the call outright when a direct path cannot be found,
 * which is roughly a fifth of the time, mostly on mobile networks. It costs
 * real bandwidth and so has to be yours; until it is set, those calls simply
 * will not connect, and it is better to know that than to wonder.
 */
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
