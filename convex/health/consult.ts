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
/**
 * Whether somebody is party to a consultation.
 *
 * The person who booked it, or the one practitioner it was addressed to.
 * Nobody else, and specifically not "anybody on the staff allowlist" — that
 * was fine when a nutritionist meant one trusted person, and became a hole
 * the moment practitioners could sign themselves up. It would have let any
 * approved practitioner read every health conversation in the app.
 */
function party(consult: any, userId: string) {
  return consult.userId === userId || consult.nutritionistId === userId
}

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
/**
 * Everyone a person may actually choose to ask.
 *
 * Approved and taking questions, nothing else. A pending application is
 * invisible here: it is a stranger's claim about their own qualifications
 * until somebody has checked it, and a directory that shows those is worse
 * than no directory at all where health advice is concerned.
 */
export const directory = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db.query("nutritionists").collect()

    const listed = rows
      // Being on the environment allowlist is itself an approval: those rows
      // predate applications and were vetted by whoever added the id.
      .filter((r) => r.active && (r.status === "approved" || staff().includes(r.userId)))
      .sort((a, b) => a.name.localeCompare(b.name))

    // Signed URLs are minted at read time rather than stored, so a photo can
    // be replaced or withdrawn without anything else having to be rewritten.
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
        price_minor: r.price_minor ?? 0,
        currency: r.currency ?? "TTD",
      }))
    )
  },
})

/**
 * The caller's own application, however it stands.
 *
 * Returns null for the overwhelming majority of people, who are not
 * practitioners and never will be. The screen uses that to decide whether it
 * is showing a form or a status.
 */
export const myApplication = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
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
      status: staff().includes(identity.subject) ? "approved" : (row.status ?? "pending"),
    }
  },
})

/**
 * Applying to appear in the directory, or editing an application already made.
 *
 * Open to anyone signed in — that is the point of it — but an application is
 * only ever a request. Editing an approved profile does not send it back for
 * checking: the person has been verified, and making them requeue because they
 * reworded their bio would mean nobody ever updates one.
 */
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
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .first()

    const doc = {
      userId: identity.subject,
      name,
      country: args.country.trim().toUpperCase(),
      credentials,
      bio: args.bio.trim(),
      specialties,
      offers_video: args.offers_video,
      // Left alone when no new file was chosen, so editing a bio does not
      // silently remove a photograph.
      photo: args.photo ?? existing?.photo,
      price_minor: Math.max(0, Math.floor(args.price_minor)),
      currency: args.currency.trim().toUpperCase() || "TTD",
      // Kept at zero so the old column stops being consulted anywhere.
      price_credits: 0,
      active: args.active,
      // An approved profile stays approved through an edit; anything else is
      // pending, including a previously declined application being redone.
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

/**
 * Approving or declining an application. Allowlist only.
 *
 * Whoever holds NUTRITIONIST_IDS is the one who checks qualifications. There
 * is no self-approval: an applicant cannot be the person who reviews them,
 * which is the whole reason the two fields are separate.
 */
export const review = mutation({
  args: { userId: v.string(), approved: v.boolean() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isStaff(identity.subject)) throw new Error("Not allowed")
    if (args.userId === identity.subject) throw new Error("Cannot review your own application")

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


/**
 * Opening a conversation with one specialist, in writing or on a call.
 *
 * The payment happens here and nowhere else. A free specialist costs nothing
 * and the charge is skipped entirely rather than being a charge of zero — that
 * distinction is what keeps a free consultation out of the credit ledger,
 * where a row saying "-0 credits" would be noise forever.
 *
 * The room is named for a video session whether or not a video service is
 * connected yet. Naming it here means the identifier exists before anybody
 * needs it, and connecting a provider later is a matter of who reads the
 * string rather than a change to any of this.
 */
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
    // A priced one opens unpaid and waits on a processor. Recording the price
    // here rather than reading it back off the profile later means a
    // practitioner raising their rate cannot change what somebody already owes.
    const now = Date.now()
    const id = await ctx.db.insert("consults", {
      userId: identity.subject,
      nutritionistId: args.specialistId,
      topic: args.topic?.trim() || (kind === "video" ? "Video consultation" : "Consultation"),
      status: "waiting",
      kind,
      room: kind === "video" ? `pos-${identity.subject.slice(-8)}-${now}` : undefined,
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

/**
 * A one-time URL for the phone to send a photograph to.
 *
 * The file goes straight from the device to Convex storage rather than through
 * the route layer, which keeps a few megabytes of JPEG out of a JSON body.
 */
export const photoUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    return await ctx.storage.generateUploadUrl()
  },
})


/**
 * What a session owes, for the payment route.
 *
 * Deliberately narrow: the amount, the currency and where the payment stands.
 * The route needs nothing else to raise a checkout, and a query that returned
 * the conversation as well would be handing a payment endpoint the messages.
 */
export const billing = query({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    // The same answer for missing and not-yours, so the error cannot be used
    // to discover which session ids are real.
    if (!row || row.userId !== identity.subject) throw new Error("No such session")

    return {
      id: row._id,
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

/**
 * Records which processor is carrying this payment, and its reference.
 *
 * Written before the person is sent to the checkout page, so a payment that
 * completes can always be traced back to a session even if they close the app
 * on the way.
 */
export const attachPayment = mutation({
  args: { id: v.id("consults"), ref: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    if (!row || row.userId !== identity.subject) throw new Error("No such session")

    await ctx.db.patch(args.id, { payment_ref: args.ref, updated_at: Date.now() })
    return { ok: true }
  },
})

/**
 * Marks a session paid.
 *
 * Only ever called after the processor has been asked directly what happened.
 * Being returned to the app from a checkout page proves nothing: the redirect
 * is a URL the payer could type themselves, and both processors say plainly
 * not to fulfil on it alone.
 */
/** Records the room a call was actually given, once one has been made. */
export const attachRoom = mutation({
  args: { id: v.id("consults"), room: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    if (!row || row.userId !== identity.subject) throw new Error("No such session")

    await ctx.db.patch(args.id, { room: args.room, updated_at: Date.now() })
    return { ok: true }
  },
})

export const markPaid = mutation({
  args: { id: v.id("consults") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const row = await ctx.db.get(args.id)
    if (!row || row.userId !== identity.subject) throw new Error("No such session")
    if (row.payment_status === "paid") return { already: true }

    await ctx.db.patch(args.id, { payment_status: "paid", updated_at: Date.now() })
    return { already: false }
  },
})

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
    if (!party(consult, identity.subject)) throw new Error("Not yours to read")

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

    if (!party(consult, identity.subject)) throw new Error("Not yours to answer")
    // Which side of the conversation this is. A message reads as "you" to the
    // person who booked and as the practitioner to them, and the row records
    // which it was rather than guessing later.
    const mine = consult.userId === identity.subject

    const body = args.body.trim()
    if (!body) throw new Error("An empty message says nothing")
    if (body.length > 4000) throw new Error("That is longer than a message")

    const now = Date.now()
    await ctx.db.insert("consult_messages", {
      consultId: args.id,
      from: mine ? "you" : "nutritionist",
      authorId: identity.subject,
      body,
      created_at: now,
    })

    await ctx.db.patch(args.id, {
      updated_at: now,
      // Only a real answer changes the state. Sending another message of your
      // own does not mean anybody has read the first one.
      status: mine ? consult.status : "answered",
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

    // Approved practitioners only, and only the consultations addressed to
    // them. A queue of everybody's conversations is not a queue, it is a
    // filing cabinet somebody left unlocked.
    const profile = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .first()
    const approved =
      (profile && profile.status === "approved") || isStaff(identity.subject)
    if (!approved) throw new Error("You are not listed as a practitioner")

    const rows = await ctx.db
      .query("consults")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect()

    // by_user indexes the person who booked; the practitioner's own consults
    // have to be found the other way round.
    const all = await ctx.db.query("consults").collect()
    const mine = all.filter((r) => r.nutritionistId === identity.subject)

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
          // Waiting on you, rather than on them. The one thing a queue is for.
          needs_reply: !last || last.from === "you",
        }
      })
    )

    // Oldest unanswered first: somebody who asked yesterday has waited longer
    // than somebody who asked an hour ago, and a queue sorted by newest hides
    // exactly the people who have been waiting.
    return withLast.sort((a, b) => {
      if (a.needs_reply !== b.needs_reply) return a.needs_reply ? -1 : 1
      return a.created_at - b.created_at
    })
  },
})
