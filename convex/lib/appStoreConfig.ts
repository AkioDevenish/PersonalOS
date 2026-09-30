/**
 * Which App Store environments a purchase may come from, read from the deployment's settings.
 * Kept free of the Apple library so it can be tested on its own.
 */

export type StoreEnvironment = "production" | "sandbox" | "xcode"

export type StoreConfig = {
  /** Tried in order. App Review buys with sandbox accounts against the production build, so a
   *  production deployment falls back to sandbox, as Apple recommends. */
  environments: StoreEnvironment[]
  /** The app's numeric Apple ID from App Store Connect, which Apple requires for production. */
  appAppleId?: number
}

export function storeConfig(env: Record<string, string | undefined>): StoreConfig {
  const setting = (env.APPLE_IAP_ENVIRONMENT || "sandbox").trim().toLowerCase()
  switch (setting) {
    case "production": {
      const id = Number(env.APPLE_APP_ID)
      if (!Number.isInteger(id) || id <= 0) {
        throw new Error("Purchase verification is not configured yet: APPLE_APP_ID is missing")
      }
      return { environments: ["production", "sandbox"], appAppleId: id }
    }
    case "sandbox":
      return { environments: ["sandbox"] }
    case "xcode":
      // Xcode's local StoreKit signs nothing Apple can vouch for, so accepting it means accepting
      // anything. It takes a second, deliberate setting, so a stray value can never do it.
      if (env.APPLE_IAP_ALLOW_UNSIGNED !== "true") {
        throw new Error("Xcode purchases are only accepted when APPLE_IAP_ALLOW_UNSIGNED is true")
      }
      return { environments: ["xcode"] }
    default:
      throw new Error(`Unknown APPLE_IAP_ENVIRONMENT "${setting}"`)
  }
}
