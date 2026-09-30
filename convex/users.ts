import { v } from "convex/values"
import { getAuthUserId } from "@convex-dev/auth/server"
import { internalMutation, mutation, query } from "./_generated/server"
import { internal } from "./_generated/api"
import { configured } from "./auth"

/** Every table that holds a person's own rows, and the index that finds them. */
const OWNED = [
  { table: "health_samples", index: "by_user_day_metric" },
  { table: "health_records", index: "by_user" },
  { table: "health_connections", index: "by_user" },
  { table: "health_oauth_tokens", index: "by_user_provider" },
  { table: "health_metric_sources", index: "by_user" },
  { table: "ai_reports", index: "by_user" },
  { table: "ai_preferences", index: "by_user" },
  { table: "ai_keys", index: "by_user" },
  { table: "activity_tracking", index: "by_user" },
  { table: "entitlements", index: "by_user" },
  { table: "purchase_receipts", index: "by_userId" },
  { table: "push_devices", index: "by_userId" },
  { table: "contacts", index: "by_user" },
  { table: "interactions", index: "by_user" },
  { table: "posts", index: "by_user" },
  { table: "projects", index: "by_user" },
  { table: "finance_entries", index: "by_user" },
  { table: "time_blocks", index: "by_user" },
  { table: "cuisine_dishes", index: "by_userId" },
  // An author's articles are keyed by the same id under another name. The payments go first so
  // none is left pointing at an article that is gone.
  { table: "article_payments", index: "by_authorToken", field: "authorToken" },
  { table: "articles", index: "by_authorToken_and_updated_at", field: "authorToken" },
] as const satisfies readonly { table: string; index: string; field?: string }[]

/** Rows deleted per run, before the sweep hands off to a fresh transaction. */
const BUDGET = 1500

/** The signed-in person's own account. */
export const me = query({
  args: {},
  handler: async (ctx) => {
    const id = await getAuthUserId(ctx)
    if (!id) return null
    const user = await ctx.db.get(id)
    if (!user) return null
    return {
      id: user._id,
      name: user.name ?? null,
      email: user.email ?? null,
      image: user.image ?? null,
    }
  },
})

export const setName = mutation({
  args: { name: v.string() },
  handler: async (ctx, args) => {
    const id = await getAuthUserId(ctx)
    if (!id) throw new Error("Not authenticated")
    const name = args.name.trim()
    if (name.length > 80) throw new Error("That is longer than a name")
    await ctx.db.patch(id, { name: name || undefined })
    return null
  },
})

/** Which ways in exist, so the app only shows buttons that work. */
export const providers = query({
  args: {},
  handler: async () => ({
    password: true,
    google: configured("GOOGLE"),
    facebook: configured("FACEBOOK"),
    apple: configured("APPLE"),
  }),
})

/** Deleting the account, from inside the app. */
export const deleteAccount = mutation({
  args: {},
  handler: async (ctx) => {
    const id = await getAuthUserId(ctx)
    if (!id) throw new Error("Not authenticated")

    const accounts = await ctx.db
      .query("authAccounts")
      .withIndex("userIdAndProvider", (q) => q.eq("userId", id))
      .take(20)
    for (const account of accounts) {
      const codes = await ctx.db
        .query("authVerificationCodes")
        .withIndex("accountId", (q) => q.eq("accountId", account._id))
        .take(50)
      for (const code of codes) await ctx.db.delete(code._id)
      await ctx.db.delete(account._id)
    }

    const sessions = await ctx.db
      .query("authSessions")
      .withIndex("userId", (q) => q.eq("userId", id))
      .take(200)
    for (const session of sessions) {
      const tokens = await ctx.db
        .query("authRefreshTokens")
        .withIndex("sessionId", (q) => q.eq("sessionId", session._id))
        .take(200)
      for (const token of tokens) await ctx.db.delete(token._id)
      await ctx.db.delete(session._id)
    }

    await ctx.db.delete(id)

    // The login is gone before this returns, so nobody can sign back in while the rest is still
    // being swept.
    await ctx.scheduler.runAfter(0, internal.users.purge, { userId: id })
    return null
  },
})

/** Deletes everything a departed account owned, a batch at a time. */
export const purge = internalMutation({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    let budget = BUDGET
    const again = async () => {
      await ctx.scheduler.runAfter(0, internal.users.purge, args)
      return null
    }

    // A practitioner's photo lives in file storage, which only the profile row points at, so it
    // goes before the row does.
    const profiles = await ctx.db
      .query("nutritionists")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .take(10)
    for (const profile of profiles) {
      if (profile.photo && (await ctx.db.system.get(profile.photo))) {
        await ctx.storage.delete(profile.photo)
      }
      await ctx.db.delete(profile._id)
      budget -= 1
    }

    for (const entry of OWNED) {
      const field = "field" in entry ? entry.field : "userId"
      while (budget > 0) {
        // The table name is a variable here, so the types collapse to the intersection of twenty
        // different row shapes and the index name narrows to never.
        const query = ctx.db.query(entry.table) as unknown as {
          withIndex: (
            name: string,
            range: (q: { eq: (field: string, value: string) => unknown }) => unknown,
          ) => { take: (count: number) => Promise<{ _id: Parameters<typeof ctx.db.delete>[0] }[]> }
        }
        const rows = await query
          .withIndex(entry.index, (q) => q.eq(field, args.userId))
          .take(Math.min(200, budget))
        if (rows.length === 0) break
        for (const row of rows) await ctx.db.delete(row._id)
        budget -= rows.length
      }
      if (budget <= 0) return await again()
    }

    // A consultation's messages and call signalling hang off the consultation rather than off the
    // person, so a consultation is only deleted once nothing points at it any more. One at a time,
    // because a long one can hold more messages than a whole run's budget.
    while (budget > 0) {
      const consult = await ctx.db
        .query("consults")
        .withIndex("by_user", (q) => q.eq("userId", args.userId))
        .first()
      if (!consult) break
      let empty = true
      for (const table of ["consult_messages", "call_signals"] as const) {
        const rows = await ctx.db
          .query(table)
          .withIndex("by_consult", (q) => q.eq("consultId", consult._id))
          .take(Math.min(200, budget))
        for (const row of rows) await ctx.db.delete(row._id)
        budget -= rows.length
        if (rows.length > 0) empty = false
      }
      if (empty) {
        await ctx.db.delete(consult._id)
        budget -= 1
      }
    }
    if (budget <= 0) return await again()

    // Consultations this person answered as a practitioner belong to the people who asked, so they
    // stay, closed and no longer tied to an account that is gone.
    while (budget > 0) {
      const consult = await ctx.db
        .query("consults")
        .withIndex("by_nutritionistId", (q) => q.eq("nutritionistId", args.userId))
        .first()
      if (!consult) break
      await ctx.db.patch(consult._id, {
        nutritionistId: undefined,
        status: "closed",
        updated_at: Date.now(),
      })
      budget -= 1
    }

    if (budget <= 0) return await again()
    return null
  },
})
