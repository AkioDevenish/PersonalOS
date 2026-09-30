import { convexAuth, createAccount, retrieveAccount } from "@convex-dev/auth/server"
import { Password } from "@convex-dev/auth/providers/Password"
import { ConvexCredentials } from "@convex-dev/auth/providers/ConvexCredentials"
import Google from "@auth/core/providers/google"
import Facebook from "@auth/core/providers/facebook"
import Apple from "@auth/core/providers/apple"
import { verifyAppleIdentityToken } from "./lib/apple"

/** Signing in, run by this app rather than by a service. */

/** Where a Google, Facebook or Apple sign-in may return to: the app itself. */
export function safeRedirect(redirectTo: string): string {
  if (redirectTo.startsWith("personalos://")) return redirectTo
  throw new Error("Sign-in can only return to the app")
}

/** Whether a provider's credentials are on the deployment. */
export function configured(name: "GOOGLE" | "FACEBOOK" | "APPLE"): boolean {
  return Boolean(process.env[`AUTH_${name}_ID`] && process.env[`AUTH_${name}_SECRET`])
}

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [
    Password({
      // One address, one account, however somebody happens to type it.
      profile(params) {
        const email = String(params.email ?? "").trim().toLowerCase()
        if (!email.includes("@")) throw new Error("That is not an email address")
        const name = String(params.name ?? "").trim()
        const profile: { email: string; name?: string } = { email }
        if (name) profile.name = name
        return profile as { email: string }
      },
      validatePasswordRequirements(password) {
        if (password.length < 8) throw new Error("Use at least 8 characters")
      },
    }),
    // Apple's own sheet on the phone. Needs no secrets on the deployment: Apple signs the token.
    ConvexCredentials({
      id: "apple-native",
      async authorize(credentials, ctx) {
        const { identityToken, nonce, name } = credentials
        if (typeof identityToken !== "string" || typeof nonce !== "string") {
          throw new Error("Apple sign-in is missing its token")
        }
        const apple = await verifyAppleIdentityToken(identityToken, nonce)
        const account = { id: apple.sub }
        try {
          const { user } = await retrieveAccount(ctx, { provider: "apple-native", account })
          return { userId: user._id }
        } catch {
          // First time: Apple shares the name only now, and only with the app, so it comes in
          // alongside the token rather than inside it.
          const profile: { email?: string; name?: string; emailVerified?: boolean } = {}
          if (apple.email) profile.email = apple.email
          if (apple.emailVerified) profile.emailVerified = true
          if (typeof name === "string" && name.trim()) profile.name = name.trim().slice(0, 80)
          const { user } = await createAccount(ctx, {
            provider: "apple-native",
            account,
            profile,
            // Joins an account that already proved it owns this address, never one that only claimed it.
            shouldLinkViaEmail: apple.emailVerified,
          })
          return { userId: user._id }
        }
      },
    }),
    ...(configured("GOOGLE") ? [Google] : []),
    ...(configured("FACEBOOK") ? [Facebook] : []),
    ...(configured("APPLE") ? [Apple] : []),
  ],
  callbacks: {
    async redirect({ redirectTo }) {
      return safeRedirect(redirectTo)
    },
  },
})
