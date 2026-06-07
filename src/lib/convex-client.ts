import { ConvexHttpClient } from "convex/browser"

export function getConvexClient(token?: string | null): any {
  const url = process.env.NEXT_PUBLIC_CONVEX_URL
  if (!url) {
    throw new Error("NEXT_PUBLIC_CONVEX_URL is not set")
  }
  const client = new ConvexHttpClient(url) as any
  if (token) {
    client.setAuth(token)
  } else if (process.env.CONVEX_DEPLOYMENT_KEY) {
    client.setAdminAuth(process.env.CONVEX_DEPLOYMENT_KEY)
  }
  return client
}
