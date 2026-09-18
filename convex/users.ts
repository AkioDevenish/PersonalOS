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
