/**
 * The Convex deployment the web app talks to. Set NEXT_PUBLIC_CONVEX_URL to override; otherwise
 * `next dev` uses dev and a production build uses production, the same split as the iOS app's
 * Debug and Release builds (ios/Forklore/AppConfig.swift).
 */
const DEV = "https://wary-penguin-35.convex.cloud"
const PROD = "https://astute-ant-253.convex.cloud"

export const CONVEX_URL =
  process.env.NEXT_PUBLIC_CONVEX_URL || (process.env.NODE_ENV === "production" ? PROD : DEV)

/** The same deployment's site, which serves /privacy, /terms and the payment return page. */
export const SITE_URL = CONVEX_URL.replace(".convex.cloud", ".convex.site")
