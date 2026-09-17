import { v } from "convex/values"
import { mutation, query } from "./_generated/server"
import type { MutationCtx, QueryCtx } from "./_generated/server"
import type { Doc, Id } from "./_generated/dataModel"
import { check, LIMITS, paragraphsOf } from "./articleRules"

/**
 * Practitioners writing for the app, and the review that stands between a
 * draft and the home screen.
 *
 *   draft ──submit──▶ submitted ──approve──▶ published
 *     ▲                   │                     │
 *     └──── edit ◀── changes_requested ◀────────┤ (edit takes it off Home)
 *                                               └──withdraw──▶ withdrawn
 *
 * Writing is limited to approved practitioners because they are the people
 * whose identity and credentials have already been checked, which is what
 * makes a review of the words, rather than of the author, enough.
 */

/** The staff allowlist, the same one that approves practitioner applications. */
function isStaff(subject: string): boolean {
  return (process.env.NUTRITIONIST_IDS ?? "")
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
  const profile = await practitionerProfile(ctx, identity.subject)
  const approved = profile?.status === "approved" || isStaff(identity.subject)
  if (!approved) throw new Error("Only approved practitioners can write articles")
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

/** Everything on Home: published, newest first. */
export const published = query({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_status_and_published_at", (q) => q.eq("status", "published"))
      .order("desc")
      .take(60)
    return await Promise.all(rows.map((row) => presented(ctx, row)))
  },
})

/** Whether this person may write, and whether they may review. */
export const abilities = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) return { canWrite: false, canReview: false }
    const profile = await practitionerProfile(ctx, identity.subject)
    const staff = isStaff(identity.subject)
    return { canWrite: profile?.status === "approved" || staff, canReview: staff }
  },
})

/** An author's own articles, in every state, with what the review said. */
export const mine = query({
  args: {},
  handler: async (ctx) => {
    const identity = await signedIn(ctx)
    const rows = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", identity.tokenIdentifier))
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
      updated_at: row.updated_at,
    }))
  },
})

// MARK: Writing

/**
 * Creates or updates a draft.
 *
 * A draft may be unfinished, so the check's errors are returned rather than
 * thrown; they block `submit`, not saving. Editing a published article takes
 * it off Home and back to draft: what readers see is always what a reviewer
 * approved, never an edit made afterwards.
 */
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
      await ownArticle(ctx, args.id, identity.tokenIdentifier)
      await ctx.db.patch(args.id, { ...fields, status: "draft", published_at: undefined })
      return { id: args.id, errors: findings.errors, flags: findings.flags }
    }

    // A generous cap on unpublished work, so one account cannot fill the table.
    const recent = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", identity.tokenIdentifier))
      .order("desc")
      .take(40)
    if (recent.filter((r) => r.status !== "published").length >= 20) {
      throw new Error("Finish or delete some drafts before starting another")
    }

    const id = await ctx.db.insert("articles", {
      ...fields,
      authorToken: identity.tokenIdentifier,
      authorId: identity.subject,
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
    const row = await ownArticle(ctx, args.id, identity.tokenIdentifier)
    if (row.status !== "draft" && row.status !== "changes_requested") {
      throw new Error("Only a draft can be sent for review")
    }

    const findings = check(row)
    if (findings.errors.length > 0) throw new Error(findings.errors.join(". "))

    // Three waiting at once is plenty; a queue one person can flood is not a queue.
    const waiting = await ctx.db
      .query("articles")
      .withIndex("by_authorToken_and_updated_at", (q) => q.eq("authorToken", identity.tokenIdentifier))
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
    await ownArticle(ctx, args.id, identity.tokenIdentifier)
    await ctx.db.patch(args.id, { status: "withdrawn", published_at: undefined, updated_at: Date.now() })
    return null
  },
})

export const remove = mutation({
  args: { id: v.id("articles") },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    const row = await ownArticle(ctx, args.id, identity.tokenIdentifier)
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
    if (!isStaff(identity.subject)) throw new Error("Not allowed")
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
        own: row.authorId === identity.subject,
      })),
    )
  },
})

/**
 * Publishes, or sends back with a note.
 *
 * The checks are run again here rather than trusted from submission, so a
 * rule tightened while an article waited applies to it too. A send-back needs
 * a note: "no" with no reason is not something an author can act on.
 */
export const review = mutation({
  args: { id: v.id("articles"), approve: v.boolean(), note: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const identity = await signedIn(ctx)
    if (!isStaff(identity.subject)) throw new Error("Not allowed")

    const row = await ctx.db.get(args.id)
    if (!row || row.status !== "submitted") throw new Error("That article is not waiting for review")
    if (row.authorId === identity.subject) throw new Error("Someone else has to review your own article")

    const now = Date.now()
    if (args.approve) {
      const findings = check(row)
      if (findings.errors.length > 0) throw new Error(findings.errors.join(". "))
      await ctx.db.patch(args.id, {
        status: "published",
        published_at: now,
        reviewed_by: identity.subject,
        review_note: args.note?.trim() || undefined,
        updated_at: now,
      })
      return { status: "published" }
    }

    const note = args.note?.trim() ?? ""
    if (note.length < 10) throw new Error("Say what needs changing, so the author can fix it")
    await ctx.db.patch(args.id, {
      status: "changes_requested",
      reviewed_by: identity.subject,
      review_note: note,
      updated_at: now,
    })
    return { status: "changes_requested" }
  },
})
