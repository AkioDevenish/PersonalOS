import { v } from "convex/values"
import { mutation, query } from "../_generated/server"

/**
 * Asking a human.
 *
 * Everything else in this app is a model reading numbers. This is the one
 * place a person can put a question to another person, which makes it the one
 * place where the app must not overstate what is happening: a consultation is
 * "waiting" until a real reply exists, and the app says so in those words.
 * Nothing here marks a request as seen, received or in progress on the
 * strength of it having been sent.
 *
 * Who counts as a nutritionist is an allowlist of Clerk user ids in the Convex
 * environment, `NUTRITIONIST_IDS`, comma separated. Deliberately not a flag on
 * a user row: a row can be written by any code path that gets it wrong, where
 * an environment variable has to be set deliberately by someone with access to
 * the deployment. The people who can read strangers' health questions should be
 * a list somebody typed on purpose.
 */

function staff(): string[] {
  return (process.env.NUTRITIONIST_IDS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
}

function isStaff(userId: string) {
  return staff().includes(userId)
}

/** Whether anyone is actually on the other end. The app says so plainly. */
export const staffed = query({
  args: {},
  handler: async () => ({ staffed: staff().length > 0 }),
})

/**
 * Your consultations, newest first, each with its last message.
 */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db
      .query("consults")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect()

    const withLast = await Promise.all(
      rows.map(async (row) => {
        const messages = await ctx.db
          .query("consult_messages")
          .withIndex("by_consult", (q) => q.eq("consultId", row._id))
          .collect()
        const last = messages.sort((a, b) => b.created_at - a.created_at)[0]
        return {
          id: row._id,
          topic: row.topic,
          status: row.status,
          created_at: row.created_at,
          updated_at: row.updated_at,
          last_message: last?.body ?? "",
          last_from: last?.from ?? "",
          replies: messages.filter((m) => m.from === "nutritionist").length,
        }
      })
    )

    return withLast.sort((a, b) => b.updated_at - a.updated_at)
  },
})

/** One conversation, in order. */
export const thread = query({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const consult = await ctx.db.get(args.id)
    if (!consult) throw new Error("No such consultation")
    // Yours, or you are one of the people paid to read it. Nothing else.
    if (consult.userId !== identity.subject && !isStaff(identity.subject)) {
      throw new Error("Not yours to read")
    }

    const messages = await ctx.db
      .query("consult_messages")
      .withIndex("by_consult", (q) => q.eq("consultId", args.id))
      .collect()

    return {
      id: consult._id,
      topic: consult.topic,
      status: consult.status,
      shared: consult.shared ?? "",
      created_at: consult.created_at,
      messages: messages
        .sort((a, b) => a.created_at - b.created_at)
        .map((m) => ({
          id: m._id,
          from: m.from,
          body: m.body,
          created_at: m.created_at,
        })),
    }
  },
})

/**
 * Opens a consultation.
 *
 * `shared` is the readings the person chose to hand over, already rendered as
 * the text they saw. Stored rather than re-read later, so the nutritionist is
 * looking at what was consented to and not at whatever the numbers say today.
 */
export const start = mutation({
  args: {
    topic: v.string(),
    question: v.string(),
    shared: v.optional(v.string()),
    country: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const topic = args.topic.trim()
    const question = args.question.trim()
    if (!question) throw new Error("A question needs asking")
    if (question.length > 4000) throw new Error("That is longer than a question")

    const now = Date.now()
    const id = await ctx.db.insert("consults", {
      userId: identity.subject,
      topic: topic || "Nutrition",
      status: "waiting",
      shared: args.shared,
      country: args.country,
      created_at: now,
      updated_at: now,
    })

    await ctx.db.insert("consult_messages", {
      consultId: id,
      from: "you",
      authorId: identity.subject,
      body: question,
      created_at: now,
    })

    return { id }
  },
})

/**
 * Adds a message. The same call for both sides — who you are decides how it
 * reads, and a reply from staff is the only thing that moves a consultation
 * out of "waiting".
 */
export const send = mutation({
  args: { id: v.id("consults"), body: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const consult = await ctx.db.get(args.id)
    if (!consult) throw new Error("No such consultation")

    const mine = consult.userId === identity.subject
    const professional = isStaff(identity.subject)
    if (!mine && !professional) throw new Error("Not yours to answer")

    const body = args.body.trim()
    if (!body) throw new Error("An empty message says nothing")
    if (body.length > 4000) throw new Error("That is longer than a message")

    const now = Date.now()
    await ctx.db.insert("consult_messages", {
      consultId: args.id,
      from: professional && !mine ? "nutritionist" : "you",
      authorId: identity.subject,
      body,
      created_at: now,
    })

    await ctx.db.patch(args.id, {
      updated_at: now,
      // Only a real answer changes the state. Sending another message of your
      // own does not mean anybody has read the first one.
      status: professional && !mine ? "answered" : consult.status,
    })

    return { ok: true }
  },
})

/** The waiting queue, for the people staffing it. */
export const queue = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isStaff(identity.subject)) throw new Error("Not a nutritionist")

    const rows = await ctx.db
      .query("consults")
      .withIndex("by_status", (q) => q.eq("status", "waiting"))
      .collect()

    return rows
      .sort((a, b) => a.created_at - b.created_at)
      .map((r) => ({
        id: r._id,
        topic: r.topic,
        country: r.country ?? "",
        created_at: r.created_at,
      }))
  },
})
