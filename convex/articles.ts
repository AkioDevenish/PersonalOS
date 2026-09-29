import { userIdOf } from "./lib/me"
import { v } from "convex/values"
import { internalMutation, mutation, query } from "./_generated/server"
import type { MutationCtx, QueryCtx } from "./_generated/server"
import type { Doc, Id } from "./_generated/dataModel"
import { internal } from "./_generated/api"
import { check, LIMITS, paragraphsOf } from "./articleRules"

/**
 * Practitioners writing for the app, the team that verifies it, and the payment that puts it on
 * Home.
 */

/** Paid time on Home per purchase. */
export const PLACEMENT_DAYS = 30
const DAY = 24 * 60 * 60 * 1000

/** The article team: who may verify articles. */
function isReviewer(subject: string): boolean {
  return (process.env.ARTICLE_REVIEWER_IDS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .includes(subject)
}

async function signedIn(ctx: QueryCtx | MutationCtx) {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) throw new Error("Not authenticated")
  return identity
}

async function practitionerProfile(ctx: QueryCtx | MutationCtx, subject: string) {
  return await ctx.db
    .query("nutritionists")
    .withIndex("by_user", (q) => q.eq("userId", subject))
    .first()
}

async function requireAuthor(ctx: MutationCtx) {
  const identity = await signedIn(ctx)
  const profile = await practitionerProfile(ctx, userIdOf(identity))
  if (profile?.status !== "approved") throw new Error("Only approved practitioners can write articles")
  return identity
}

async function ownArticle(ctx: MutationCtx, id: Id<"articles">, token: string) {
  const row = await ctx.db.get(id)
  // One answer for missing and not yours, so ids cannot be probed.
  if (!row || row.authorToken !== token) throw new Error("No such article")
  return row
}

/** What a reader, or the app, is shown of an article. */
async function presented(ctx: QueryCtx, row: Doc<"articles">) {
  const profile = await practitionerProfile(ctx, row.authorId)
  return {
    id: row._id,
    title: row.title,
    category: row.category,
    minutes: row.minutes,
    symbol: row.symbol,
    colour: row.colour,
    summary: row.summary,
    body: paragraphsOf(row.body),
    author: profile?.name ?? null,
    credentials: profile?.credentials ?? null,
    published_at: row.published_at ?? null,
  }
}

const articleFields = {
  title: v.string(),
  category: v.string(),
  summary: v.string(),
  body: v.string(),
  symbol: v.string(),
  colour: v.string(),
}

// MARK: Reading

/** Whether this reader has a subscription. */
/** Off unless the PAYWALL env var is "on", so every signed-in reader gets the full archive. */
const paywallOn = () => process.env.PAYWALL === "on"

async function subscribes(ctx: QueryCtx, now: number): Promise<boolean> {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) return false
  if (!paywallOn()) return true
  const row = await ctx.db
    .query("entitlements")
    .withIndex("by_user", (q) => q.eq("userId", userIdOf(identity)))
    .first()
  if (row?.subscription_status !== "active") return false
  return typeof row.expires_at !== "number" || row.expires_at > now
}

/** Everything on Home, newest first. */
export const published = query({
  args: { now: v.number() },
  handler: async (ctx, args) => {
    const unlocked = await subscribes(ctx, args.now)
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_status_and_published_at", (q) => q.eq("status", "published"))
      .order("desc")
      .take(60)
    return await Promise.all(
      rows.map(async (row) => {
        const shown = await presented(ctx, row)
        return { ...shown, body: unlocked ? shown.body : [], locked: !unlocked }
      }),
    )
  },
})

/** The archive: articles whose paid time on Home has run out. */
export const archive = query({
  args: { now: v.number() },
  handler: async (ctx, args) => {
    const unlocked = await subscribes(ctx, args.now)
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_status_and_published_at", (q) => q.eq("status", "expired"))
      .order("desc")
      .take(60)
    return await Promise.all(
      rows.map(async (row) => {
        const shown = await presented(ctx, row)
        return { ...shown, body: unlocked ? shown.body : [], locked: !unlocked }
      }),
    )
  },
})

/** Whether this person may write, and whether they may review. */
export const abilities = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) return { canWrite: false, canReview: false }
    const profile = await practitionerProfile(ctx, userIdOf(identity))
    return { canWrite: profile?.status === "approved", canReview: isReviewer(userIdOf(identity)) }
  },
})

/** An author's own articles, in every state, with what the review said. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const identity = await signedIn(ctx)
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", userIdOf(identity)))
      .order("desc")
      .take(50)
    return rows.map((row) => ({
      id: row._id,
      title: row.title,
      category: row.category,
      summary: row.summary,
      body: row.body,
      symbol: row.symbol,
      colour: row.colour,
      minutes: row.minutes,
      status: row.status,
      flags: row.flags,
      review_note: row.review_note ?? null,
      live_until: row.live_until ?? null,
      updated_at: row.updated_at,
    }))
  },
})

// MARK: Writing

/** Creates or updates a draft. */
export const save = mutation({
  args: { id: v.optional(v.id("articles")), ...articleFields },
  handler: async (ctx, args) => {
    const identity = await requireAuthor(ctx)
    if (args.body.length > LIMITS.bodyCharacters) throw new Error("That is longer than an article")
    if (!args.title.trim()) throw new Error("Give it a title first")

    const findings = check(args)
    const now = Date.now()
    const fields = {
      title: args.title.trim(),
      category: args.category,
      summary: args.summary.trim(),
      body: findings.paragraphs.join("\n\n"),
      symbol: args.symbol,
      colour: args.colour,
      minutes: findings.minutes,
      flags: findings.flags,
      updated_at: now,
    }

    if (args.id) {
      await ownArticle(ctx, args.id, userIdOf(identity))
      await ctx.db.patch(args.id, { ...fields, status: "draft", published_at: undefined })
      return { id: args.id, errors: findings.errors, flags: findings.flags }
    }

    // A generous cap on unpublished work, so one account cannot fill the table.
    const recent = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", userIdOf(identity)))
      .order("desc")
      .take(40)
    if (recent.filter((r) => r.status !== "published").length >= 20) {
      throw new Error("Finish or delete some drafts before starting another")
    }

    const id = await ctx.db.insert("articles", {
      ...fields,
      authorToken: userIdOf(identity),
      authorId: userIdOf(identity),
      status: "draft",
    })
    return { id, errors: findings.errors, flags: findings.flags }
  },
})

/** Sends a draft for review, if and only if it passes every automatic check. */
export const submit = mutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const identity = await requireAuthor(ctx)
    const row = await ownArticle(ctx, args.id, userIdOf(identity))
    if (row.status !== "draft" && row.status !== "changes_requested") {
      throw new Error("Only a draft can be sent for review")
    }

    const findings = check(row)
    if (findings.errors.length > 0) throw new Error(findings.errors.join(". "))

    // Three waiting at once is plenty; a queue one person can flood is not a queue.
    const waiting = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", userIdOf(identity)))
      .order("desc")
      .take(40)
    if (waiting.filter((r) => r.status === "submitted").length >= 3) {
      throw new Error("You already have three articles waiting for review")
    }

    const now = Date.now()
    await ctx.db.patch(args.id, {
      status: "submitted",
      flags: findings.flags,
      minutes: findings.minutes,
      review_note: undefined,
      submitted_at: now,
      updated_at: now,
    })
    return { flags: findings.flags }
  },
})

/** Takes an article off Home, or out of the queue, without losing the words. */
export const withdraw = mutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    await ownArticle(ctx, args.id, userIdOf(identity))
    // Withdrawing gives up whatever paid time was left; there is no pause.
    await ctx.db.patch(args.id, { status: "withdrawn", live_until: undefined, updated_at: Date.now() })
    return null
  },
})

export const remove = mutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    const row = await ownArticle(ctx, args.id, userIdOf(identity))
    if (row.status === "published") throw new Error("Withdraw it from Home before deleting it")
    await ctx.db.delete(args.id)
    return null
  },
})

// MARK: Reviewing

/** Oldest first: whoever has waited longest is read next. */
export const queue = query({
  args: {},
  handler: async (ctx) => {
    const identity = await signedIn(ctx)
    if (!isReviewer(userIdOf(identity))) throw new Error("Not allowed")
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_status_and_submitted_at", (q) => q.eq("status", "submitted"))
      .order("asc")
      .take(50)
    return await Promise.all(
      rows.map(async (row) => ({
        ...(await presented(ctx, row)),
        flags: row.flags,
        submitted_at: row.submitted_at ?? null,
        own: row.authorId === userIdOf(identity),
      })),
    )
  },
})

/** Verifies, or sends back with a note. */
export const review = mutation({
  args: { id: v.id("articles"), approve: v.boolean(), note: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    if (!isReviewer(userIdOf(identity))) throw new Error("Not allowed")

    const row = await ctx.db.get(args.id)
    if (!row || row.status !== "submitted") throw new Error("That article is not waiting for review")
    if (row.authorId === userIdOf(identity)) throw new Error("Someone else has to review your own article")

    const now = Date.now()
    if (args.approve) {
      const findings = check(row)
      if (findings.errors.length > 0) throw new Error(findings.errors.join(". "))
      const stillPaid = (row.live_until ?? 0) > now
      await ctx.db.patch(args.id, {
        status: stillPaid ? "published" : "approved",
        published_at: stillPaid ? (row.published_at ?? now) : row.published_at,
        reviewed_by: userIdOf(identity),
        review_note: args.note?.trim() || undefined,
        updated_at: now,
      })
      // The expiry job for that time may already have run while the article was a draft, and found
      // nothing to do.
      if (stillPaid) await ctx.scheduler.runAt(row.live_until!, internal.articles.expire, { id: args.id })
      await ctx.scheduler.runAfter(0, internal.push.send, {
        userId: row.authorId,
        title: "Your article was verified",
        body: stillPaid ? "It is back on Home." : "Pay to put it on Home for 30 days.",
      })
      return { status: stillPaid ? "published" : "approved" }
    }

    const note = args.note?.trim() ?? ""
    if (note.length < 10) throw new Error("Say what needs changing, so the author can fix it")
    await ctx.db.patch(args.id, {
      status: "changes_requested",
      reviewed_by: userIdOf(identity),
      review_note: note,
      updated_at: now,
    })
    await ctx.scheduler.runAfter(0, internal.push.send, {
      userId: row.authorId,
      title: "Your article needs a change",
      body: "The reviewer left a note on it.",
    })
    return { status: "changes_requested" }
  },
})

// MARK: Paying

/** The token a purchase must carry to count for this article. */
export const startPayment = mutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    const row = await ownArticle(ctx, args.id, userIdOf(identity))
    if (row.status !== "approved" && row.status !== "published" && row.status !== "expired") {
      throw new Error("An article can be paid for once the team has verified it")
    }
    const token = row.payment_token ?? crypto.randomUUID()
    if (!row.payment_token) await ctx.db.patch(args.id, { payment_token: token })
    return { token, days: PLACEMENT_DAYS }
  },
})

/** Applies a purchase that articlePayments.ts has verified against Apple. */
export const applyPlacement = internalMutation({
  args: {
    authorToken: v.string(),
    paymentToken: v.string(),
    transactionId: v.string(),
    productId: v.string(),
  },
  handler: async (ctx, args) => {
    const seen = await ctx.db
      .query("article_payments")
      .withIndex("by_transactionId", (q) => q.eq("transactionId", args.transactionId))
      .first()
    if (seen) return { applied: false, live_until: seen.live_until }

    const row = await ctx.db
      .query("articles")
      .withIndex("by_payment_token", (q) => q.eq("payment_token", args.paymentToken))
      .first()
    if (!row || row.authorToken !== args.authorToken) throw new Error("That purchase is not for one of your articles")
    if (row.status !== "approved" && row.status !== "published" && row.status !== "expired") {
      throw new Error("That article is not verified for publishing")
    }

    const now = Date.now()
    const from = row.status === "published" && (row.live_until ?? 0) > now ? row.live_until! : now
    const liveUntil = from + PLACEMENT_DAYS * DAY

    await ctx.db.patch(row._id, {
      status: "published",
      published_at: row.status === "published" ? (row.published_at ?? now) : now,
      live_until: liveUntil,
      updated_at: now,
    })
    await ctx.db.insert("article_payments", {
      articleId: row._id,
      authorToken: args.authorToken,
      transactionId: args.transactionId,
      productId: args.productId,
      live_until: liveUntil,
      created_at: now,
    })
    // Taken down when the time runs out.
    await ctx.scheduler.runAt(liveUntil, internal.articles.expire, { id: row._id })
    return { applied: true, live_until: liveUntil }
  },
})

/** Takes an article off Home when its paid time has run out. */
export const expire = internalMutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.id)
    if (!row || row.status !== "published") return null
    if ((row.live_until ?? 0) > Date.now()) return null
    await ctx.db.patch(args.id, { status: "expired", updated_at: Date.now() })
    return null
  },
})
