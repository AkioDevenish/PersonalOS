"use client"

import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import StoryClient from "@/components/landing/story-client"
import sh from "@/components/shared.module.css"

export default function LandingPage() {
  return (
    <div className={sh.page}>
      <SiteHeader />

      <main>
        <StoryClient isSignedIn={false} />
      </main>

      <SiteFooter />
    </div>
  )
}
