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

/**
 * The nutritionists a person can choose from.
 *
 * Only those who have written a profile and marked it active: being on the
 * allowlist makes you able to answer, not visible to ask. Someone who hasn't
 * said who they are shouldn't appear on a list of people you might trust with
 * your glucose.
 */
export const professionals = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db
      .query("nutritionists")
      .withIndex("by_active", (q) => q.eq("active", true))
      .collect()

    return rows
      .filter((r) => staff().includes(r.userId))
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((r) => ({
        id: r.userId,
        name: r.name,
        country: r.country,
        credentials: r.credentials,
        bio: r.bio,
        price_credits: r.price_credits,
      }))
  },
})

/**
 * A nutritionist writing their own profile.
 *
 * Their own, and only their own: the allowlist decides who may answer, and
 * this decides nothing except how they introduce themselves.
 */
export const upsertProfile = mutation({
  args: {
    name: v.string(),
    country: v.string(),
    credentials: v.string(),
    bio: v.string(),
    price_credits: v.number(),
    active: v.boolean(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isStaff(identity.subject)) throw new Error("Not a nutritionist")

    const existing = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .first()

    const doc = {
      userId: identity.subject,
      name: args.name.trim(),
      country: args.country.trim().toUpperCase(),
      credentials: args.credentials.trim(),
      bio: args.bio.trim(),
      price_credits: Math.max(0, Math.floor(args.price_credits)),
      active: args.active,
      updated_at: Date.now(),
    }
    if (existing) {
      await ctx.db.patch(existing._id, doc)
      return existing._id
    }
    return await ctx.db.insert("nutritionists", doc)
  },
})

/**
 * Charges for a consultation, the same way the rest of the app charges.
 *
 * A subscription covers it; otherwise it costs credits, and the ledger records
 * the spend so a balance can always be explained. Enforced here rather than in
 * the app, because a price the client can decide not to charge is not a price.
 */
async function charge(ctx: any, userId: string, amount: number, reason: string) {
  if (amount <= 0) return

  const row = await ctx.db
    .query("entitlements")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first()

  const subscribed =
    row?.subscription_status === "active" &&
    (typeof row.expires_at !== "number" || row.expires_at > Date.now())
  if (subscribed) return

  const balance = row?.credits ?? 0
  if (balance < amount) {
    throw new Error(
      `This consultation costs ${amount} ${amount === 1 ? "credit" : "credits"}. Subscribe or add credits to send it.`
    )
  }

  await ctx.db.patch(row._id, { credits: balance - amount, updated_at: Date.now() })
  await ctx.db.insert("ai_credit_ledger", {
    userId,
    delta: -amount,
    reason,
    created_at: Date.now(),
  })
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
    nutritionistId: v.optional(v.string()),
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

    // Charged before anything is written. A consultation that exists but was
    // never paid for is worse than one that was refused: the person waits for
    // an answer that isn't coming.
    let price = 0
    if (args.nutritionistId) {
      const profile = await ctx.db
        .query("nutritionists")
        .withIndex("by_user", (q) => q.eq("userId", args.nutritionistId!))
        .first()
      if (!profile || !profile.active) throw new Error("That nutritionist isn't taking questions")
      price = profile.price_credits
    }
    await charge(ctx, identity.subject, price, `consult:${args.nutritionistId ?? "any"}`)

    const now = Date.now()
    const id = await ctx.db.insert("consults", {
      userId: identity.subject,
      nutritionistId: args.nutritionistId,
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
