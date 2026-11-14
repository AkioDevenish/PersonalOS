"use client"
import { ConvexAuthProvider } from "@convex-dev/auth/react"
import { ConvexReactClient } from "convex/react"
import { CONVEX_URL } from "@/web/convexUrl"

const client = new ConvexReactClient(CONVEX_URL)

/** One Convex client for the whole tab, signed in with the token @convex-dev/auth keeps. */
export function Providers({ children }: { children: React.ReactNode }) {
  return <ConvexAuthProvider client={client}>{children}</ConvexAuthProvider>
}
