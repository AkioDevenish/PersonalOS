"use client"

import { useEffect, useRef } from "react"
import Link from "next/link"
import {
  BarChart3,
  HeartPulse,
  Workflow,
  Sparkles,
  ArrowRight,
  Check,
  Brain,
  Shield,
  Play,
} from "lucide-react"
import { Logo } from "@/components/ui/logo"
import { HeroBackground } from "@/components/hero/hero-background"
import { useAuth } from "@clerk/nextjs"
import { useRouter } from "next/navigation"

const NAV_ITEMS = [
  { href: "#features", label: "Features" },
  { href: "#how-it-works", label: "Workflow" },
  { href: "#pricing", label: "Pricing" },
]

const FEATURES = [
  {
    icon: HeartPulse,
    color: "var(--sage)",
    bgColor: "var(--sage-low)",
    title: "Health & Well-being",
    description:
      "Sync automatically with Apple Health, track your metabolic events, and get personalized, AI-driven nutrition and recovery recommendations daily.",
  },
  {
    icon: Workflow,
    color: "var(--amber)",
    bgColor: "var(--amber-low)",
    title: "Business CRM",
    description:
      "Manage deals, track follow-ups, and log communications. Never let an opportunity slip through the cracks again.",
  },
  {
    icon: Sparkles,
    color: "#C75B5B",
    bgColor: "rgba(199,91,91,0.12)",
    title: "Content Marketing",
    description:
      "Schedule posts, track compounding social media metrics, and maintain a sustainable content pipeline.",
  },
  {
    icon: BarChart3,
    color: "var(--dust)",
    bgColor: "rgba(168,149,126,0.2)",
    title: "Local AI Analytics",
    description:
      "Your data stays on your machine. Powerful local models analyze your activity and habits without sending anything to the cloud.",
  },
]

const STEPS = [
  { number: "01", title: "Connect", description: "Sync your health data, link your accounts, and import your existing workflows — all in under five minutes." },
  { number: "02", title: "Personalize", description: "Your dashboard adapts to your life. Configure the modules that matter to you, hide what doesn't." },
  { number: "03", title: "Let AI Guide You", description: "Local AI models analyze your patterns and suggest actions, content, and improvements — daily." },
]

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

function FeatureCard({ feature }: { feature: (typeof FEATURES)[0] }) {
  const Icon = feature.icon
  return (
    <article
      className="group relative bg-[var(--warm-white)] rounded-2xl p-8 border border-[var(--border-subtle)] shadow-sm
        hover:shadow-md hover:-translate-y-0.5 transition-all duration-300
        saas-scroll-reveal"
    >
      <div
        className="absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none"
        style={{ background: `linear-gradient(135deg, ${feature.color}0a, transparent 60%)` }}
      />
      <div className="relative z-10">
        <div
          className="w-11 h-11 rounded-xl flex items-center justify-center mb-5 transition-transform duration-300 group-hover:scale-110"
          style={{ backgroundColor: feature.bgColor, color: feature.color }}
        >
          <Icon className="w-5 h-5" />
        </div>
        <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mb-2.5">{feature.title}</h3>
        <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed">{feature.description}</p>

      </div>
    </article>
  )
}

export default function SaaSLandingPage() {
  const headerRef = useRef<HTMLElement>(null)

  const { isSignedIn, isLoaded } = useAuth()
  const router = useRouter()

  useScrollFallback(headerRef)

  useEffect(() => {
    if (isLoaded && isSignedIn) router.push("/hub")
  }, [isLoaded, isSignedIn, router])

  return (
    <div className="min-h-screen bg-[var(--linen)] text-[var(--deep-brown)] overflow-x-hidden selection:bg-[var(--amber-low)]/60">

      {/* ── Fixed Header ── */}
      <header
        ref={headerRef}
        className="fixed top-0 left-0 right-0 z-50 px-5 md:px-8 py-6 saas-header flex items-center justify-between"
      >
        <Link href="/" aria-label="Personal OS — Home">
          <Logo size={36} showText />
        </Link>

        {/* Desktop nav */}
        <nav className="hidden md:flex items-center gap-8" aria-label="Main navigation">
          {NAV_ITEMS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-[13px] text-[var(--mid-brown)] hover:text-[var(--deep-brown)] font-medium tracking-wide transition-colors"
            >
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

      <main>
        {/* ══════════════════════════════════════
             HERO
           ══════════════════════════════════════ */}
        <section className="relative min-h-[100svh] px-5 pt-28 pb-16 overflow-hidden hero-front-page">
          <HeroBackground />

          <div className="relative z-10 mx-auto flex min-h-[calc(100svh-11rem)] max-w-7xl flex-col justify-center animate-fade-in">
            <div className="hero-kicker">
              Personal operating system / private AI workspace
            </div>

            <h1 className="hero-title">
              PERSONAL
              <span>OS</span>
            </h1>

            <p className="hero-subtitle">
              One beautiful front door for your health, business, marketing, and daily
              signal. Designed like a studio object, powered by local intelligence.
            </p>

            <div className="hero-actions">
              {isLoaded && !isSignedIn && (
                <>
                  <Link
                    href="/sign-up"
                    className="hero-primary-action"
                  >
                    Get Started
                    <ArrowRight className="w-4 h-4" />
                  </Link>
                  <Link
                    href="#features"
                    className="hero-secondary-action"
                  >
                    <Play className="w-4 h-4" />
                    Explore System
                  </Link>
                </>
              )}
              {isLoaded && isSignedIn && (
                <Link
                  href="/hub"
                  className="hero-primary-action"
                >
                  Go to Your Dashboard
                  <ArrowRight className="w-4 h-4" />
                </Link>
              )}
            </div>

            <div className="hero-trust-row">
              {[
                { icon: Shield, text: "Your data, your machine" },
                { icon: Brain, text: "Local AI first" },
                { icon: Check, text: "No cloud dependency" },
              ].map(({ icon: Icon, text }) => (
                <span key={text} className="flex items-center gap-1.5">
                  <Icon className="w-3.5 h-3.5 text-[var(--sage)]" />
                  {text}
                </span>
              ))}
            </div>
          </div>
        </section>

        {/* ══════════════════════════════════════
             FEATURES
           ══════════════════════════════════════ */}
        <section id="features" className="px-5 py-24 max-w-6xl mx-auto scroll-mt-28">
          <div className="text-center mb-16">
            <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
              Capabilities
            </span>
            <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-4">
              Stop context-switching.
            </h2>
            <p className="text-[var(--mid-brown)] max-w-lg mx-auto">
              Run your life from a single, beautiful dashboard.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {FEATURES.map((feature, i) => (
              <FeatureCard key={feature.title} feature={feature} />
            ))}
          </div>
        </section>

        {/* ══════════════════════════════════════
             HOW IT WORKS
           ══════════════════════════════════════ */}
        <section id="how-it-works" className="px-5 py-24 max-w-5xl mx-auto scroll-mt-28">
          <div className="text-center mb-16">
            <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
              Workflow
            </span>
            <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-4">
              Minutes to set up. A lifetime of clarity.
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-10 md:gap-14">
            {STEPS.map((step) => (
              <div key={step.number} className="text-center saas-scroll-reveal">
                <div className="w-14 h-14 rounded-2xl bg-[var(--warm-white)] border border-[var(--border-subtle)] flex items-center justify-center mx-auto mb-6 shadow-sm">
                  <span className="font-display text-xl font-bold text-[var(--amber)]">{step.number}</span>
                </div>
                <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mb-3">{step.title}</h3>
                <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed max-w-xs mx-auto">{step.description}</p>
              </div>
            ))}
          </div>
        </section>

        {/* ══════════════════════════════════════
              PRICING
           ══════════════════════════════════════ */}
        <section id="pricing" className="px-5 py-24 max-w-6xl mx-auto scroll-mt-28">
          <div className="text-center mb-16">
            <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
              Pricing
            </span>
            <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-4">
              Simple, transparent pricing
            </h2>
            <p className="text-[var(--mid-brown)] max-w-lg mx-auto">
              Start free, upgrade when you need more.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              {
                tier: "STARTER",
                name: "Personal Dashboard",
                subtitle: "Perfect for getting started",
                price: "Free",
                features: [
                  "Health & well-being tracking",
                  "Business CRM (up to 10 deals)",
                  "Content marketing drafts",
                  "Local AI analytics",
                  "1 user",
                ],
                cta: "Get Started",
                href: "/sign-up",
                featured: false,
              },
              {
                tier: "PRO",
                name: "Full Workspace",
                subtitle: "Unlock everything",
                price: "$12",
                period: "/month",
                features: [
                  "Everything in Starter",
                  "Unlimited deals & contacts",
                  "AI-powered content generation",
                  "Advanced health insights",
                  "Custom AI model selection",
                  "Priority support",
                ],
                cta: "Start Free Trial",
                href: "/sign-up",
                featured: true,
              },
              {
                tier: "ENTERPRISE",
                name: "Team Workspace",
                subtitle: "For teams and power users",
                price: "$29",
                period: "/month",
                features: [
                  "Everything in Pro",
                  "Up to 5 team members",
                  "Shared deal pipelines",
                  "Team health dashboards",
                  "API access",
                  "Dedicated support",
                ],
                cta: "Contact Sales",
                href: "mailto:sales@personalos.com",
                featured: false,
              },
            ].map((tier) => (
              <div
                key={tier.tier}
                className={`relative bg-[var(--warm-white)] rounded-3xl p-8 border saas-scroll-reveal transition-all duration-300
                  ${tier.featured
                    ? "border-[var(--border-mid)] shadow-lg ring-1 ring-[var(--amber)]/20"
                    : "border-[var(--border-subtle)] shadow-sm hover:shadow-md"
                  }`}
              >
                {tier.featured && (
                  <div className="absolute -top-3 left-8 px-4 py-1 bg-[var(--amber)] text-[var(--warm-white)] text-[10px] uppercase tracking-[0.12em] font-semibold rounded-full">
                    Most Popular
                  </div>
                )}

                <div>
                  <div className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-3">
                    {tier.tier}
                  </div>
                  <h3 className="font-display text-2xl font-bold text-[var(--deep-brown)] mb-1">
                    {tier.name}
                  </h3>
                  <p className="text-[13px] text-[var(--dust)] mb-6">
                    {tier.subtitle}
                  </p>

                  <div className="flex items-baseline gap-1 mb-6">
                    {tier.price === "Free" ? (
                      <span className="text-5xl font-bold font-display tracking-tight text-[var(--deep-brown)]">
                        Free
                      </span>
                    ) : (
                      <>
                        <span className="text-5xl font-bold font-display tracking-tight text-[var(--deep-brown)]">
                          {tier.price}
                        </span>
                        {tier.period && (
                          <span className="text-[14px] text-[var(--dust)]">{tier.period}</span>
                        )}
                      </>
                    )}
                  </div>

                  <div className="h-px bg-[var(--border-subtle)] mb-6" />

                  <ul className="space-y-3 mb-8">
                    {tier.features.map((f) => (
                      <li key={f} className="flex items-start gap-3 text-[13px]">
                        <Check className="w-4 h-4 mt-0.5 flex-shrink-0 text-[var(--sage)]" />
                        <span className="text-[var(--mid-brown)]">{f}</span>
                      </li>
                    ))}
                  </ul>

                  <Link
                    href={tier.href}
                    className={`w-full flex items-center justify-center px-5 py-3.5 rounded-xl text-[13px] font-medium transition-all
                      hover:scale-[1.02] active:scale-[0.98]
                      ${tier.featured
                        ? "bg-[var(--deep-brown)] text-[var(--warm-white)] hover:opacity-90 shadow-md"
                        : "bg-[var(--deep-brown)] text-[var(--warm-white)] hover:opacity-85 shadow-sm"
                      }`}
                  >
                    {tier.cta}
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </section>


      </main>

      {/* ── Footer ── */}
      <footer className="border-t border-[var(--border-subtle)] py-16 px-5 bg-[var(--warm-white)]/30">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-10 mb-12">
            <div className="col-span-2 md:col-span-1">
              <Logo size={32} showText />
              <p className="text-[12px] text-[var(--dust)] mt-3 leading-relaxed max-w-[200px]">
                Your unified operating system for health, business, and creativity.
              </p>
            </div>
            {[
              {
                title: "Product",
                links: [
                  { href: "#features", label: "Features" },
                  { href: "#how-it-works", label: "How It Works" },
                  { href: "#pricing", label: "Pricing" },
                  { href: "/privacy", label: "Privacy" },
                  { href: "/terms", label: "Terms" },
                ],
              },
              {
                title: "Careers",
                links: [
                  { href: "https://x.com", label: "We&apos;re Hiring" },
                  { href: "mailto:careers@personalos.com", label: "Contact HR" },
                ],
              },
              {
                title: "Social",
                links: [],
              },
            ].map((group) => (
              <div key={group.title}>
                <div className="text-[11px] uppercase tracking-[0.12em] text-[var(--dust)] font-semibold mb-4">
                  {group.title}
                </div>
                {group.links.length > 0 && (
                  <ul className="space-y-3">
                    {group.links.map((link) => (
                      <li key={link.label}>
                        <Link
                          href={link.href}
                          className="text-[13px] text-[var(--mid-brown)] hover:text-[var(--deep-brown)] transition-colors"
                        >
                          {link.label}
                        </Link>
                      </li>
                    ))}
                  </ul>
                )}
                {group.title === "Social" && (
                  <div className="flex gap-4">
                    <a href="https://x.com" target="_blank" rel="noopener noreferrer" className="text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors" aria-label="X">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M4 4l11.733 16h4.267l-11.733 -16z" />
                        <path d="M4 20l6.768 -6.768m2.46 -2.46L20 4" />
                      </svg>
                    </a>
                    <a href="https://youtube.com" target="_blank" rel="noopener noreferrer" className="text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors" aria-label="YouTube">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M2 8a4 4 0 0 1 4 -4h12a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4H6a4 4 0 0 1 -4 -4V8z" />
                        <path d="M10 9l5 3l-5 3V9z" />
                      </svg>
                    </a>
                    <a href="https://instagram.com" target="_blank" rel="noopener noreferrer" className="text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors" aria-label="Instagram">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                        <rect x="2" y="2" width="20" height="20" rx="5" />
                        <circle cx="12" cy="12" r="5" />
                        <circle cx="17.5" cy="6.5" r="1" fill="currentColor" />
                      </svg>
                    </a>
                    <a href="https://tiktok.com" target="_blank" rel="noopener noreferrer" className="text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors" aria-label="TikTok">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M9 12a4 4 0 1 0 4 4V4a5 5 0 0 0 5 5" />
                      </svg>
                    </a>
                  </div>
                )}
              </div>
            ))}
          </div>

          <div className="pt-8 border-t border-[var(--border-subtle)] flex flex-col sm:flex-row items-center justify-between gap-4">
            <p className="text-[12px] text-[var(--dust)]">
              &copy; {new Date().getFullYear()} Personal OS. All rights reserved.
            </p>
            <div className="flex gap-6">
              <Link href="/privacy" className="text-[12px] text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors">
                Privacy
              </Link>
              <Link href="/terms" className="text-[12px] text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors">
                Terms
              </Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
