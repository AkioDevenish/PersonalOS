import { userIdOf } from "../lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query } from "../_generated/server"
import { internal } from "../_generated/api"

/** Asking a human. */

function staff(): string[] {
  return (process.env.NUTRITIONIST_IDS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
}

function isStaff(userId: string) {
  return staff().includes(userId)
}

/** Whether somebody is party to a consultation. */
function party(consult: any, userId: string) {
  return consult.userId === userId || consult.nutritionistId === userId
}

/** Everyone a person may actually choose to ask. */
export const directory = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db.query("nutritionists").collect()

    const fresh = Date.now() - 3 * 60 * 1000

    const listed = rows
      // Being on the environment allowlist is itself an approval: those rows predate applications
      // and were vetted by whoever added the id.
      .filter((r) => r.active && (r.status === "approved" || staff().includes(r.userId)))
      // Whoever can answer now, first.
      .sort((a, b) => {
        const onA = (a.last_seen ?? 0) > fresh
        const onB = (b.last_seen ?? 0) > fresh
        if (onA !== onB) return onA ? -1 : 1
        if (onA && onB) return (b.last_seen ?? 0) - (a.last_seen ?? 0)
        return a.name.localeCompare(b.name)
      })

    // Signed URLs are minted at read time rather than stored, so a photo can be replaced or
    // withdrawn without anything else having to be rewritten.
    return await Promise.all(
      listed.map(async (r) => ({
        id: r.userId,
        name: r.name,
        country: r.country,
        credentials: r.credentials,
        bio: r.bio,
        specialties: r.specialties ?? [],
        offers_video: r.offers_video ?? false,
        photo_url: r.photo ? await ctx.storage.getUrl(r.photo) : null,
        last_seen: r.last_seen ?? 0,
        price_minor: r.price_minor ?? 0,
        currency: r.currency ?? "TTD",
      }))
    )
  },
})

/** The caller's own application, however it stands. */
export const myApplication = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()

    if (!row) return null
    return {
      photo_url: row.photo ? await ctx.storage.getUrl(row.photo) : null,
      price_minor: row.price_minor ?? 0,
      currency: row.currency ?? "TTD",
      name: row.name,
      country: row.country,
      credentials: row.credentials,
      bio: row.bio,
      specialties: row.specialties ?? [],
      offers_video: row.offers_video ?? false,
      active: row.active,
      status: staff().includes(userIdOf(identity)) ? "approved" : (row.status ?? "pending"),
    }
  },
})

/** Applying to appear in the directory, or editing an application already made. */
export const apply = mutation({
  args: {
    name: v.string(),
    country: v.string(),
    credentials: v.string(),
    bio: v.string(),
    specialties: v.array(v.string()),
    offers_video: v.boolean(),
    photo: v.optional(v.id("_storage")),
    price_minor: v.number(),
    currency: v.string(),
    active: v.boolean(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const name = args.name.trim()
    const credentials = args.credentials.trim()
    if (!name) throw new Error("A name is required")
    if (!credentials) throw new Error("Your qualifications are required")

    const specialties = args.specialties
      .map((s) => s.trim())
      .filter(Boolean)
      .slice(0, 6)
    if (specialties.length === 0) throw new Error("Name at least one specialism")

    const existing = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()

    const doc = {
      userId: userIdOf(identity),
      name,
      country: args.country.trim().toUpperCase(),
      credentials,
      bio: args.bio.trim(),
      specialties,
      offers_video: args.offers_video,
      // Left alone when no new file was chosen, so editing a bio does not silently remove a
      // photograph.
      photo: args.photo ?? existing?.photo,
      price_minor: Math.max(0, Math.floor(args.price_minor)),
      currency: args.currency.trim().toUpperCase() || "TTD",
      // Kept at zero so the old column stops being consulted anywhere.
      price_credits: 0,
      active: args.active,
      // An approved profile stays approved through an edit; anything else is pending, including a
      // previously declined application being redone.
      status: existing?.status === "approved" ? "approved" : "pending",
      updated_at: Date.now(),
    }

    if (existing) {
      await ctx.db.patch(existing._id, doc)
      return { status: doc.status }
    }
    await ctx.db.insert("nutritionists", doc)
    return { status: doc.status }
  },
})

/** Approving or declining an application. */
export const review = mutation({
  args: { userId: v.string(), approved: v.boolean() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isStaff(userIdOf(identity))) throw new Error("Not allowed")
    if (args.userId === userIdOf(identity)) throw new Error("Cannot review your own application")

    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .first()
    if (!row) throw new Error("No such application")

    await ctx.db.patch(row._id, {
      status: args.approved ? "approved" : "declined",
      updated_at: Date.now(),
    })
    return { status: args.approved ? "approved" : "declined" }
  },
})

/** Opening a conversation with one specialist, in writing or on a call. */
export const openSession = mutation({
  args: {
    specialistId: v.string(),
    kind: v.string(),          // "text" | "video"
    topic: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const kind = args.kind === "video" ? "video" : "text"

    const profile = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", args.specialistId))
      .first()

    const approved =
      profile && profile.active &&
      (profile.status === "approved" || staff().includes(profile.userId))
    if (!approved) throw new Error("That specialist is not taking questions")

    if (kind === "video" && !(profile.offers_video ?? false)) {
      throw new Error(`${profile.name} does not take video calls`)
    }

    const priceMinor = Math.max(0, Math.floor(profile.price_minor ?? 0))
    const currency = (profile.currency ?? "TTD").toUpperCase()

    // Free means free: nothing to collect, so the session opens outright.
    const now = Date.now()
    const id = await ctx.db.insert("consults", {
      userId: userIdOf(identity),
      nutritionistId: args.specialistId,
      topic: args.topic?.trim() || (kind === "video" ? "Video consultation" : "Consultation"),
      status: "waiting",
      kind,
      room: kind === "video" ? `pos-${userIdOf(identity).slice(-8)}-${now}` : undefined,
      price_minor: priceMinor,
      currency,
      payment_status: priceMinor === 0 ? "free" : "pending",
      created_at: now,
      updated_at: now,
    })

    return {
      id,
      kind,
      price_minor: priceMinor,
      currency,
      payment_status: priceMinor === 0 ? "free" : "pending",
    }
  },
})

/** A one-time URL for the phone to send a photograph to. */
export const photoUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.storage.generateUploadUrl()
  },
})

/** What a session owes, for the payment route. */
export const billing = query({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    // The same answer for missing and not-yours, so the error cannot be used to discover which
    // session ids are real.
    if (!row || row.userId !== userIdOf(identity)) throw new Error("No such session")

    return {
      id: row._id,
      practitionerId: row.nutritionistId ?? "",
      price_minor: row.price_minor ?? 0,
      currency: row.currency ?? "TTD",
      payment_status: row.payment_status ?? "free",
      payment_ref: row.payment_ref ?? null,
      kind: row.kind ?? "text",
      room: row.room ?? null,
      topic: row.topic,
    }
  },
})

/** Records which processor is carrying this payment, and its reference. */
export const attachPayment = mutation({
  args: {
    id: v.id("consults"),
    ref: v.string(),
    /** The platform's share, worked out server-side from the price. */
    feeMinor: v.optional(v.number()),
    /** True when the payment was not split and the practitioner is owed. */
    owed: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    if (!row || row.userId !== userIdOf(identity)) throw new Error("No such session")

    await ctx.db.patch(args.id, {
      payment_ref: args.ref,
      platform_fee_minor: args.feeMinor,
      payout_owed: args.owed,
      updated_at: Date.now(),
    })
    return { ok: true }
  },
})

/** "I am here." */
export const heartbeat = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) return { beat: false }

    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()
    if (!row) return { beat: false }

    await ctx.db.patch(row._id, { last_seen: Date.now() })
    return { beat: true }
  },
})

/** Marks a session paid. */
/** Marks a session paid. */
export const markPaidVerified = internalMutation({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.id)
    if (!row) throw new Error("No such session")
    if (row.payment_status === "paid") return { already: true }
    await ctx.db.patch(args.id, { payment_status: "paid", updated_at: Date.now() })
    return { already: false }
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
    if (!party(consult, userIdOf(identity))) throw new Error("Not yours to read")

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

/** Adds a message. */
export const send = mutation({
  args: { id: v.id("consults"), body: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const consult = await ctx.db.get(args.id)
    if (!consult) throw new Error("No such consultation")

    if (!party(consult, userIdOf(identity))) throw new Error("Not yours to answer")
    // Which side of the conversation this is.
    const mine = consult.userId === userIdOf(identity)

    const body = args.body.trim()
    if (!body) throw new Error("An empty message says nothing")
    if (body.length > 4000) throw new Error("That is longer than a message")

    const now = Date.now()
    await ctx.db.insert("consult_messages", {
      consultId: args.id,
      from: mine ? "you" : "nutritionist",
      authorId: userIdOf(identity),
      body,
      created_at: now,
    })

    await ctx.db.patch(args.id, {
      updated_at: now,
      // Only a real answer changes the state.
      status: mine ? consult.status : "answered",
    })

    // Tell the other side, on their lock screen, because the whole point of a written consultation
    // is that neither person has to sit in the app.
    const other = mine ? consult.nutritionistId : consult.userId
    if (other) {
      await ctx.scheduler.runAfter(0, internal.push.send, {
        userId: other,
        title: "Spoonful",
        body: mine ? "Someone has sent you a question." : "Your practitioner has replied.",
        route: "specialists",
      })
    }

    return { ok: true }
  },
})

/** The waiting queue, for the people staffing it. */
export const queue = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    // Approved practitioners only, and only the consultations addressed to them.
    const profile = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
      .first()
    const approved =
      (profile && profile.status === "approved") || isStaff(userIdOf(identity))
    if (!approved) throw new Error("You are not listed as a practitioner")

    // by_user indexes the person who booked; the practitioner's own consults have to be found the
    // other way round.
    const all = await ctx.db.query("consults").collect()
    const mine = all.filter((r) => r.nutritionistId === userIdOf(identity))

    const withLast = await Promise.all(
      mine.map(async (r) => {
        const messages = await ctx.db
          .query("consult_messages")
          .withIndex("by_consult", (q) => q.eq("consultId", r._id))
          .collect()
        const sorted = messages.sort((a, b) => a.created_at - b.created_at)
        const last = sorted[sorted.length - 1]
        return {
          id: r._id,
          topic: r.topic,
          kind: r.kind ?? "text",
          status: r.status,
          payment_status: r.payment_status ?? "free",
          created_at: r.created_at,
          updated_at: r.updated_at,
          replies: sorted.length,
          last_message: last?.body ?? "",
          // Waiting on you, rather than on them.
          needs_reply: !last || last.from === "you",
        }
      })
    )

    // Oldest unanswered first: somebody who asked yesterday has waited longer than somebody who
    // asked an hour ago, and a queue sorted by newest hides exactly the people who have been
    // waiting.
    return withLast.sort((a, b) => {
      if (a.needs_reply !== b.needs_reply) return a.needs_reply ? -1 : 1
      return a.created_at - b.created_at
    })
  },
})
