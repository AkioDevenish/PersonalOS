import { v } from "convex/values"
import { getAuthUserId } from "@convex-dev/auth/server"
import { mutation, query } from "./_generated/server"
import { configured } from "./auth"

/**
 * The signed-in person's own account.
 *
 * What Clerk's profile screen used to show and edit, now that the account is
 * a row in this database.
 */
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

/**
 * Which ways in exist, so the app only shows buttons that work.
 *
 * Deliberately public: the sign-in screen needs it before anybody has signed
 * in, and it says nothing beyond which providers are set up.
 */
export const providers = query({
  args: {},
  handler: async () => ({
    password: true,
    google: configured("GOOGLE"),
    facebook: configured("FACEBOOK"),
    apple: configured("APPLE"),
  }),
})

/**
 * Deleting the account, from inside the app.
 *
 * Apple requires this of any app that lets people create an account
 * (guideline 5.1.1(v)): it has to be possible without writing to anybody.
 *
 * Removes the account and everything that signs in as it — its sign-in
 * methods, its sessions, and those sessions' refresh tokens — so nothing
 * held on a phone can sign in again afterwards.
 */
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
    return null
  },
})
