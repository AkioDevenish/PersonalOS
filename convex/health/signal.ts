import { userIdOf } from "../lib/me"
import { requireSettled } from "../lib/consults"
import { v } from "convex/values"
import { internalMutation, mutation, query, type QueryCtx } from "../_generated/server"
import type { Id } from "../_generated/dataModel"
import { internal } from "../_generated/api"

/** Carrying the messages that let two phones connect a call. */

/** What one side can say while setting up a call. */
const signalKind = v.union(
  v.literal("offer"),
  v.literal("answer"),
  v.literal("candidate"),
  v.literal("bye"),
)

/** A session description is a few kilobytes; anything near this is not one. */
const MAX_PAYLOAD = 32_000

/** More than a call could need, even redialled many times over. */
const MAX_SIGNALS = 500

/** A call is set up in seconds, so what is older than this is only clutter. */
const KEEP_FOR_MS = 24 * 60 * 60 * 1000

/** Who may take part: the person who booked, or the practitioner they booked. */
async function participant(ctx: QueryCtx, consultId: Id<"consults">, userId: string) {
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
    kind: signalKind,
    payload: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    requireSettled(await participant(ctx, args.id, userIdOf(identity)))
    if (args.payload.length > MAX_PAYLOAD) throw new Error("That is too large to be part of a call")

    const existing = await ctx.db
      .query("call_signals")
      .withIndex("by_consult", (q) => q.eq("consultId", args.id))
      .take(MAX_SIGNALS)
    if (existing.length >= MAX_SIGNALS) throw new Error("Too many attempts to connect this call")

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
      .take(MAX_SIGNALS)

    // Already in time order, from the index.
    return rows
      .filter((r) => r.from !== userIdOf(identity))
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
      .take(MAX_SIGNALS)
    await Promise.all(rows.map((r) => ctx.db.delete(r._id)))
    return { cleared: rows.length }
  },
})

/** Sweeps away signalling from calls that ended long ago, oldest first. */
export const sweep = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - KEEP_FOR_MS
    const rows = await ctx.db
      .query("call_signals")
      .withIndex("by_creation_time", (q) => q.lt("_creationTime", cutoff))
      .take(500)
    for (const row of rows) await ctx.db.delete(row._id)
    if (rows.length === 500) await ctx.scheduler.runAfter(0, internal.health.signal.sweep, {})
    return { swept: rows.length }
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
