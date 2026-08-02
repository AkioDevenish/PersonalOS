"use client"

import { useEffect, useRef } from "react"
import Link from "next/link"
import { ArrowRight } from "lucide-react"
import { useAuth } from "@clerk/nextjs"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"
import { NAV_ITEMS } from "./nav"

function useScrollFallback(headerRef: React.RefObject<HTMLElement | null>) {
  useEffect(() => {
    if (
      typeof CSS !== "undefined" &&
      CSS.supports("(animation-timeline: scroll()) and (animation-range: 0% 100%)")
    )
      return

    const onScroll = () => {
      const el = headerRef.current
      if (!el) return
      const t = Math.min(1, window.scrollY / 150)
      const pad = 24 - (24 - 12) * t
      el.style.paddingTop = `${pad}px`
      el.style.paddingBottom = `${pad}px`
      el.style.backgroundColor = `rgba(249, 246, 240, ${0.92 * t})`
      el.style.backdropFilter = `blur(${16 * t}px)`
      if (t > 0) {
        el.style.boxShadow = "0 1px 3px rgba(40,32,15,0.04)"
        el.style.borderBottom = "1px solid rgba(40,32,15,0.10)"
      } else {
        el.style.boxShadow = "none"
        el.style.borderBottom = "none"
      }
    }
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => window.removeEventListener("scroll", onScroll)
  }, [headerRef])
}

export default function SiteHeader() {
  const headerRef = useRef<HTMLElement>(null)
  const { isSignedIn, isLoaded } = useAuth()

  useScrollFallback(headerRef)

  return (
    <header
      ref={headerRef}
      className="fixed top-0 left-0 right-0 z-50 px-5 md:px-8 py-6 saas-header flex items-center justify-between"
    >
      <Link href="/" aria-label="Personal OS — Home" className={sh.logoWrap}>
        <span className={sh.logoDisc}>
          <img className={sh.logoMark} src="/story/time.jpg" alt="" />
        </span>
        <span className={sh.logoText}>
          <span className={sh.logoName}>Personal OS</span>
          <span className={sh.logoTag}>Time Well Spent</span>
        </span>
      </Link>

      <nav className={s.siteNav} aria-label="Main navigation">
        {NAV_ITEMS.map((item) => (
          <Link key={item.href} href={item.href} className={s.siteNavLink}>
            {item.label}
          </Link>
        ))}
      </nav>

      <div className="flex items-center gap-3">
        {isLoaded ? (
          isSignedIn ? (
            <Link
              href="/hub"
              className="bg-[var(--deep-brown)] text-[var(--warm-white)] px-5 py-2.5 rounded-xl text-[13px] font-medium
                hover:opacity-85 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-sm flex items-center gap-2"
            >
              Dashboard
              <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          ) : (
            <>
              <Link
                href="/sign-in"
                className="hidden sm:inline-flex text-[13px] text-[var(--mid-brown)] hover:text-[var(--deep-brown)] font-medium transition-colors px-3 py-2"
              >
                Sign In
              </Link>
              <Link
                href="/sign-up"
                className="bg-[var(--deep-brown)] text-[var(--warm-white)] px-5 py-2.5 rounded-xl text-[13px] font-medium
                  hover:opacity-85 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-sm flex items-center gap-2"
              >
                Get Started
                <ArrowRight className="w-3.5 h-3.5" />
              </Link>
            </>
          )
        ) : (
          <div className="w-24 h-9 rounded-xl bg-[var(--border-subtle)] animate-pulse" />
        )}
      </div>
    </header>
  )
}
