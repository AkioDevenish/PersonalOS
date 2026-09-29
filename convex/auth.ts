import { convexAuth } from "@convex-dev/auth/server"
import { Password } from "@convex-dev/auth/providers/Password"
import Google from "@auth/core/providers/google"
import Facebook from "@auth/core/providers/facebook"
import Apple from "@auth/core/providers/apple"

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
