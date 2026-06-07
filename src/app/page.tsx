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
  Activity,
  Brain,
  Shield,
  Quote,
} from "lucide-react"
import { Logo } from "@/components/ui/logo"
import { useAuth } from "@clerk/nextjs"
import { useRouter } from "next/navigation"

const NAV_ITEMS = [
  { href: "#features", label: "Features" },
  { href: "#how-it-works", label: "How It Works" },
  { href: "#testimonials", label: "Testimonials" },
]

const FEATURES = [
  {
    icon: HeartPulse,
    color: "var(--sage)",
    bgColor: "var(--sage-low)",
    title: "Health & Well-being",
    description:
      "Sync automatically with Apple Health, track your metabolic events, and get personalized, AI-driven nutrition and recovery recommendations daily.",
    stat: "47 biomarkers tracked",
  },
  {
    icon: Workflow,
    color: "var(--amber)",
    bgColor: "var(--amber-low)",
    title: "Business CRM",
    description:
      "Manage deals, track follow-ups, and log communications. Never let an opportunity slip through the cracks again.",
    stat: "Pipeline automations",
  },
  {
    icon: Sparkles,
    color: "#C75B5B",
    bgColor: "rgba(199,91,91,0.12)",
    title: "Content Marketing",
    description:
      "Schedule posts, track compounding social media metrics, and maintain a sustainable content pipeline.",
    stat: "AI-generated drafts",
  },
  {
    icon: BarChart3,
    color: "var(--dust)",
    bgColor: "rgba(168,149,126,0.2)",
    title: "Local AI Analytics",
    description:
      "Your data stays on your machine. Powerful local models analyze your activity and habits without sending anything to the cloud.",
    stat: "100% private",
  },
]

const STEPS = [
  { number: "01", title: "Connect", description: "Sync your health data, link your accounts, and import your existing workflows — all in under five minutes." },
  { number: "02", title: "Personalize", description: "Your dashboard adapts to your life. Configure the modules that matter to you, hide what doesn't." },
  { number: "03", title: "Let AI Guide You", description: "Local AI models analyze your patterns and suggest actions, content, and improvements — daily." },
]

const TESTIMONIALS = [
  {
    quote: "I've stopped using three separate apps. Personal OS replaced my health tracker, CRM, and content scheduler in one place.",
    author: "Alex Chen",
    role: "Independent Consultant",
  },
  {
    quote: "The local AI recommendations are eerily accurate. It knows when I need rest before I do.",
    author: "Sarah Mitchell",
    role: "Software Engineer",
  },
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

function FeatureCard({ feature, index }: { feature: (typeof FEATURES)[0]; index: number }) {
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
        <div className="mt-5 pt-4 border-t border-[var(--border-subtle)] flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: feature.color }} />
          <span className="text-[11px] text-[var(--dust)] tracking-wide">{feature.stat}</span>
        </div>
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
        <section className="relative min-h-[90vh] flex items-center justify-center px-5 pt-28 pb-20 overflow-hidden">
          {/* Ambient glow orbs */}
          <div className="absolute inset-0 pointer-events-none select-none" aria-hidden>
            <div
              className="absolute top-[20%] left-[15%] w-[32rem] h-[32rem] rounded-full opacity-20 animate-pulse"
              style={{ backgroundColor: "var(--amber-low)", filter: "blur(120px)", animationDuration: "8s" }}
            />
            <div
              className="absolute bottom-[15%] right-[10%] w-[28rem] h-[28rem] rounded-full opacity-15 animate-pulse"
              style={{ backgroundColor: "var(--sage-low)", filter: "blur(100px)", animationDuration: "10s", animationDelay: "1s" }}
            />
            <div
              className="absolute top-[40%] right-[20%] w-[20rem] h-[20rem] rounded-full opacity-10 animate-pulse"
              style={{ backgroundColor: "#E8553D", filter: "blur(90px)", animationDuration: "12s", animationDelay: "2s" }}
            />
          </div>

          <div className="relative z-10 max-w-4xl mx-auto text-center animate-fade-in">
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-[var(--amber-low)]/25 border border-[var(--amber-low)]/40 text-[11px] text-[var(--amber)] font-semibold tracking-[0.08em] uppercase mb-8">
              <Activity className="w-3.5 h-3.5" />
              <span>The Operating System for Your Life</span>
            </div>

            {/* Headline */}
            <h1 className="font-display text-5xl sm:text-6xl md:text-[5.5rem] lg:text-[6.5rem] font-bold tracking-tight leading-[0.92] mb-6 text-[var(--deep-brown)]">
              Everything in
              <br />
              <span className="text-[var(--amber)]">its right place.</span>
            </h1>

            <p className="text-base sm:text-lg text-[var(--mid-brown)] max-w-xl mx-auto mb-10 leading-relaxed">
              Consolidate your well-being, business CRM, marketing content, and daily
              metrics into one unified, intelligent workspace powered by local AI.
            </p>

            {/* CTAs */}
            <div className="flex items-center justify-center gap-4 flex-wrap">
              {isLoaded && !isSignedIn && (
                <>
                  <Link
                    href="/sign-up"
                    className="bg-[#E8553D] text-white px-7 py-3 rounded-xl font-medium text-[15px]
                      hover:opacity-90 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-md
                      flex items-center gap-2"
                  >
                    Start Free Trial
                    <ArrowRight className="w-4 h-4" />
                  </Link>
                  <Link
                    href="#features"
                    className="bg-[var(--warm-white)] text-[var(--deep-brown)] px-7 py-3 rounded-xl font-medium text-[15px]
                      border border-[var(--border-mid)] hover:bg-[var(--soft-warm)] transition-colors shadow-sm"
                  >
                    See How It Works
                  </Link>
                </>
              )}
              {isLoaded && isSignedIn && (
                <Link
                  href="/hub"
                  className="bg-[#E8553D] text-white px-7 py-3 rounded-xl font-medium text-[15px]
                    hover:opacity-90 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-md
                    flex items-center gap-2"
                >
                  Go to Your Dashboard
                  <ArrowRight className="w-4 h-4" />
                </Link>
              )}
            </div>

            {/* Trust bar */}
            <div className="mt-14 flex items-center justify-center gap-6 sm:gap-8 flex-wrap text-[12px] text-[var(--dust)]">
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
             STATS
           ══════════════════════════════════════ */}
        <section className="border-y border-[var(--border-subtle)] bg-[var(--warm-white)]/40">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8 py-14 px-6 max-w-4xl mx-auto">
            {[
              { label: "Health Metrics Tracked", value: "47+" },
              { label: "AI Models Running", value: "4" },
              { label: "Lines of Code", value: "15K+" },
              { label: "Data Stays Local", value: "100%" },
            ].map((s) => (
              <div key={s.label} className="text-center">
                <div className="text-3xl md:text-4xl font-bold text-[var(--deep-brown)] font-display tracking-tight">
                  {s.value}
                </div>
                <div className="text-[11px] uppercase tracking-[0.12em] text-[var(--dust)] mt-1.5">{s.label}</div>
              </div>
            ))}
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
              <FeatureCard key={feature.title} feature={feature} index={i} />
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
             TESTIMONIALS
           ══════════════════════════════════════ */}
        <section id="testimonials" className="px-5 py-24 max-w-5xl mx-auto scroll-mt-28">
          <div className="text-center mb-16">
            <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
              Testimonials
            </span>
            <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-4">
              Loved by builders
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {TESTIMONIALS.map((t) => (
              <blockquote
                key={t.author}
                className="bg-[var(--warm-white)] rounded-2xl p-8 border border-[var(--border-subtle)] shadow-sm saas-scroll-reveal"
              >
                <Quote className="w-8 h-8 text-[var(--amber-low)] mb-4" />
                <p className="text-[14px] text-[var(--mid-brown)] leading-relaxed mb-6">&ldquo;{t.quote}&rdquo;</p>
                <footer>
                  <cite className="not-italic">
                    <div className="text-[13px] font-medium text-[var(--deep-brown)]">{t.author}</div>
                    <div className="text-[11px] text-[var(--dust)]">{t.role}</div>
                  </cite>
                </footer>
              </blockquote>
            ))}
          </div>
        </section>

        {/* ══════════════════════════════════════
             CTA
           ══════════════════════════════════════ */}
        <section className="px-5 py-24 max-w-3xl mx-auto text-center">
          <div className="bg-[var(--deep-brown)] rounded-3xl p-10 md:p-16 shadow-xl saas-scroll-reveal">
            <Brain className="w-10 h-10 text-[var(--amber)] mx-auto mb-6" />
            <h2 className="font-display text-3xl md:text-4xl font-bold text-[var(--warm-white)] mb-4">
              Ready to clear the noise?
            </h2>
            <p className="text-[14px] text-[var(--dust)] max-w-md mx-auto mb-8 leading-relaxed">
              Start your free trial today. No credit card required.
            </p>
            {isLoaded && !isSignedIn && (
              <Link
                href="/sign-up"
                className="inline-flex bg-[#E8553D] text-white px-8 py-3 rounded-xl font-medium text-[15px]
                  hover:opacity-90 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-lg
                  items-center gap-2"
              >
                Start Free Trial
                <ArrowRight className="w-4 h-4" />
              </Link>
            )}
            {isLoaded && isSignedIn && (
              <Link
                href="/hub"
                className="inline-flex bg-[#E8553D] text-white px-8 py-3 rounded-xl font-medium text-[15px]
                  hover:opacity-90 transition-all hover:scale-[1.02] active:scale-[0.98] shadow-lg
                  items-center gap-2"
              >
                Go to Dashboard
                <ArrowRight className="w-4 h-4" />
              </Link>
            )}
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
                  { href: "/sign-up", label: "Pricing" },
                ],
              },
              {
                title: "Resources",
                links: [
                  { href: "#testimonials", label: "Testimonials" },
                  { href: "/privacy", label: "Privacy Policy" },
                  { href: "/terms", label: "Terms of Service" },
                ],
              },
              {
                title: "Company",
                links: [
                  { href: "mailto:hello@personalos.com", label: "Contact" },
                  { href: "https://x.com", label: "X / Twitter" },
                  { href: "https://github.com", label: "GitHub" },
                ],
              },
            ].map((group) => (
              <div key={group.title}>
                <div className="text-[11px] uppercase tracking-[0.12em] text-[var(--dust)] font-semibold mb-4">
                  {group.title}
                </div>
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
              </div>
            ))}
          </div>

          <div className="pt-8 border-t border-[var(--border-subtle)] flex flex-col sm:flex-row items-center justify-between gap-4">
            <p className="text-[12px] text-[var(--dust)]">
              &copy; {new Date().getFullYear()} Personal OS. All rights reserved.
            </p>
            <div className="flex gap-6">
              <Link href="/privacy" className="text-[12px] text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors">
                Privacy Policy
              </Link>
              <Link href="/terms" className="text-[12px] text-[var(--dust)] hover:text-[var(--mid-brown)] transition-colors">
                Terms of Service
              </Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
