"use client"

import { useEffect } from "react"
import { useAuth } from "@clerk/nextjs"
import { useRouter } from "next/navigation"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import StoryClient from "@/components/landing/story-client"
import sh from "@/components/shared.module.css"

export default function LandingPage() {
  const { isSignedIn, isLoaded } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (isLoaded && isSignedIn) router.push("/hub")
  }, [isLoaded, isSignedIn, router])

  return (
    <div className={sh.page}>
      <SiteHeader />

      <main>
        <StoryClient isSignedIn={!!isSignedIn} />
      </main>

      <SiteFooter />
    </div>
  )
}
