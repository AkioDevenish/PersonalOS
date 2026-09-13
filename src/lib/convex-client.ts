import { ConvexHttpClient } from "convex/browser"

/// Environment values arrive with whitespace more often than anyone expects —
/// `echo "$v" | vercel env add` bakes a trailing newline into the stored value,
/// and every variable on this project was created that way. A newline is
/// invisible in a dashboard, survives a redeploy, and is truthy, so an empty
/// key reads as a present one. Trim on the way in and the class of bug is gone.
function env(name: string): string | undefined {
  const raw = process.env[name]
  const trimmed = raw?.trim()
  return trimmed ? trimmed : undefined
}

export function getConvexClient(token?: string | null): any {
  const url = env("NEXT_PUBLIC_CONVEX_URL")
  if (!url) {
    throw new Error("NEXT_PUBLIC_CONVEX_URL is not set")
  }
  const client = new ConvexHttpClient(url) as any
  const deployKey = env("CONVEX_DEPLOYMENT_KEY")
  if (token?.trim()) {
    client.setAuth(token.trim())
  } else if (deployKey) {
    client.setAdminAuth(deployKey)
  }
  return client
}
