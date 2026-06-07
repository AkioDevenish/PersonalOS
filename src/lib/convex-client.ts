import { ConvexHttpClient } from "convex/browser"

let client: ConvexHttpClient | null = null

export function getConvexClient(): ConvexHttpClient {
  if (!client) {
    const url = process.env.NEXT_PUBLIC_CONVEX_URL
    if (!url) {
      throw new Error("NEXT_PUBLIC_CONVEX_URL is not set")
    }
    const c = new ConvexHttpClient(url) as any
    if (process.env.CONVEX_DEPLOYMENT_KEY) {
      c.setAdminAuth(process.env.CONVEX_DEPLOYMENT_KEY)
    }
    client = c
  }
  return client
}
