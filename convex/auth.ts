import { convexAuth } from "@convex-dev/auth/server"
import { Password } from "@convex-dev/auth/providers/Password"
import Google from "@auth/core/providers/google"
import Facebook from "@auth/core/providers/facebook"
import Apple from "@auth/core/providers/apple"

/**
 * Signing in, run by this app rather than by a service.
 *
 * Accounts live in this database (see authTables in schema.ts), passwords are
 * hashed here, and the tokens the phone carries are signed with this
 * deployment's own key. There is no third party holding the list of users.
 *
 * Email and password work as soon as this is deployed. Google, Facebook and
 * Apple are switched on by their credentials existing — AUTH_GOOGLE_ID and
 * AUTH_GOOGLE_SECRET, AUTH_FACEBOOK_ID and AUTH_FACEBOOK_SECRET,
 * AUTH_APPLE_ID and AUTH_APPLE_SECRET — so a provider that has not been set
 * up is simply not offered, rather than offered and broken.
 */

/**
 * Where a Google, Facebook or Apple sign-in may return to: the app itself.
 *
 * The phone opens the provider's page in a secure browser sheet that closes
 * the moment it is sent to this scheme, carrying a one-time code the app
 * exchanges for its tokens. Nowhere else is accepted, so a sign-in cannot be
 * steered to a site that would keep the code.
 */
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
