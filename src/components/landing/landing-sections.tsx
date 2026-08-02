import Link from "next/link"
import {
  Activity,
  BookOpen,
  Briefcase,
  Heart,
  Sparkles,
  Check,
  ArrowRight,
  Cpu,
  Key,
  Layers,
  Users,
} from "lucide-react"

const PILLARS = [
  {
    icon: Heart,
    title: "Health",
    color: "var(--sage)",
    bg: "var(--sage-low)",
    body: "Pulls from Apple Health or Samsung Health — walks, runs, glucose, sleep, and more. Delivers daily, weekly, and monthly insights as if you had a data scientist, physician, trainer, and dietitian on call. Recommends meals from your readings and flags when something needs a clinic visit.",
  },
  {
    icon: BookOpen,
    title: "Education",
    color: "var(--amber)",
    bg: "var(--amber-low)",
    body: "Tracks learning goals, courses, and skill growth. Surfaces what to study next based on your pace and gaps — without juggling another app dashboard every morning.",
  },
  {
    icon: Briefcase,
    title: "Business & Finances",
    color: "#6E5D45",
    bg: "rgba(110,93,69,0.12)",
    body: "Unifies deals, cash flow, and follow-ups. AI watches patterns across accounts and nudges you before opportunities slip — one lens instead of ten tabs.",
  },
  {
    icon: Users,
    title: "Relationships",
    color: "#C75B5B",
    bg: "rgba(199,91,91,0.12)",
    body: "Remembers who matters, when you last connected, and what’s due. Gentle prompts to show up for people — integrated, not another contact manager to open.",
  },
  {
    icon: Sparkles,
    title: "Purpose",
    color: "var(--dust)",
    bg: "rgba(168,149,126,0.2)",
    body: "Long-horizon goals, reflection, and alignment. Connects the other pillars so progress in health and work feeds meaning — not isolated metrics.",
  },
]

export function AboutSection() {
  return (
    <section id="about" className="px-5 py-24 max-w-4xl mx-auto scroll-mt-28">
      <div className="text-center mb-12 saas-scroll-reveal">
        <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
          About Us
        </span>
        <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-6">
          One place for the life you’re already living.
        </h2>
        <p className="text-[var(--mid-brown)] text-base leading-relaxed max-w-2xl mx-auto">
          Phones and computers expect you to meet them — open ten apps, check email, log a workout,
          review finances. Personal OS inverts that. It pulls your data through seamless integrations,
          layers AI on top, and gives you a single surface that improves with you. Minimal setup.
          Bring your own keys. Start free with local models.
        </p>
      </div>
    </section>
  )
}

export function HowItWorksSection() {
  return (
    <section id="how-it-works" className="px-5 py-24 scroll-mt-28 bg-[var(--warm-white)]/40 border-y border-[var(--border-subtle)]">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16 saas-scroll-reveal">
          <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
            How it works
          </span>
          <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-5">
            Five pillars. One operating system.
          </h2>
          <p className="text-[var(--mid-brown)] max-w-3xl mx-auto leading-relaxed">
            Today’s tools scatter your life across silos. Apple Health logs your steps — but you still
            open the app to see trends. Email, banking, and CRM each demand attention. Personal OS
            ingests that data for you, runs AI across it, and returns actionable guidance without the
            daily bottleneck of context-switching.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 mb-20">
          {PILLARS.map((pillar) => {
            const Icon = pillar.icon
            return (
              <article
                key={pillar.title}
                className="bg-[var(--warm-white)] rounded-2xl p-7 border border-[var(--border-subtle)] shadow-sm saas-scroll-reveal"
              >
                <div
                  className="w-11 h-11 rounded-xl flex items-center justify-center mb-5"
                  style={{ backgroundColor: pillar.bg, color: pillar.color }}
                >
                  <Icon className="w-5 h-5" />
                </div>
                <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mb-3">
                  {pillar.title}
                </h3>
                <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed">{pillar.body}</p>
              </article>
            )
          })}

          <article className="bg-[var(--linen)] rounded-2xl p-7 border border-dashed border-[var(--border-mid)] saas-scroll-reveal flex flex-col justify-center">
            <div className="w-11 h-11 rounded-xl flex items-center justify-center mb-5 bg-[var(--amber-low)]/40 text-[var(--amber)]">
              <Layers className="w-5 h-5" />
            </div>
            <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mb-3">
              Your sixth pillar
            </h3>
            <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed">
              The system is self-extending. Community-built skills — like ChatGPT or Claude
              extensions — can be installed into your Personal OS. Someone ships a finance pillar;
              you add it in one step.
            </p>
          </article>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 max-w-5xl mx-auto">
          {[
            {
              step: "01",
              title: "Connect quietly",
              text: "Link Apple Health, Samsung Health, email, calendars, and accounts. Data flows in the background — no daily ritual of opening each app.",
            },
            {
              step: "02",
              title: "AI reads the whole picture",
              text: "Local or cloud models analyze patterns across pillars. Health gets hourly snapshots; finances get weekly rollups — whatever the domain needs.",
            },
            {
              step: "03",
              title: "You get one briefing",
              text: "Improvement areas, meal ideas, follow-up reminders, and alerts land in one hub. Configure almost nothing: BYOK or use Gemma via Ollama to start.",
            },
          ].map((item) => (
            <div key={item.step} className="text-center saas-scroll-reveal">
              <div className="font-display text-3xl font-bold text-[var(--amber)]/80 mb-4">{item.step}</div>
              <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mb-3">{item.title}</h3>
              <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed">{item.text}</p>
            </div>
          ))}
        </div>

        <div className="mt-16 flex flex-wrap items-center justify-center gap-6 text-[12px] text-[var(--dust)] saas-scroll-reveal">
          <span className="flex items-center gap-2">
            <Cpu className="w-4 h-4 text-[var(--sage)]" />
            Gemma &amp; Ollama ready
          </span>
          <span className="flex items-center gap-2">
            <Key className="w-4 h-4 text-[var(--sage)]" />
            BYOK supported
          </span>
          <span className="flex items-center gap-2">
            <Activity className="w-4 h-4 text-[var(--sage)]" />
            Health MVP live
          </span>
        </div>
      </div>
    </section>
  )
}

export function PricingSection({ isSignedIn }: { isSignedIn: boolean }) {
  const tiers = [
    {
      name: "Free",
      subtitle: "Get started with zero cost",
      price: "Free",
      period: null as string | null,
      featured: false,
      features: [
        "Connect Gemma via Ollama or any free local model",
        "Bring your own API keys (BYOK)",
        "Health pillar: walks, runs, daily & weekly insights",
        "Limited integrations & community skills browse",
        "Local-first data on your machine",
      ],
      cta: "Start Free",
      href: "/sign-up",
    },
    {
      name: "Pro",
      subtitle: "Full platform + premium models",
      price: "$12",
      period: "/month",
      featured: true,
      features: [
        "Everything in Free",
        "Full website & all five pillars",
        "Claude, ChatGPT, and hosted model access",
        "Install & publish community skills",
        "Advanced health: glucose-aware meal recs, alerts",
        "Priority support",
      ],
      cta: "Upgrade to Pro",
      href: "/sign-up",
    },
  ]

  return (
    <section id="pricing" className="px-5 py-24 max-w-4xl mx-auto scroll-mt-28">
      <div className="text-center mb-16 saas-scroll-reveal">
        <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
          Pricing
        </span>
        <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)] mb-4">
          Free to run. Pay when you need more.
        </h2>
        <p className="text-[var(--mid-brown)] max-w-lg mx-auto">
          Use Gemma and Ollama at no cost, or unlock the full OS with frontier models.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {tiers.map((tier) => (
          <div
            key={tier.name}
            className={`relative bg-[var(--warm-white)] rounded-3xl p-8 border saas-scroll-reveal transition-all duration-300
              ${tier.featured
                ? "border-[var(--border-mid)] shadow-lg ring-1 ring-[var(--amber)]/20"
                : "border-[var(--border-subtle)] shadow-sm"
              }`}
          >
            {tier.featured && (
              <div className="absolute -top-3 left-8 px-4 py-1 bg-[var(--amber)] text-[var(--warm-white)] text-[10px] uppercase tracking-[0.12em] font-semibold rounded-full">
                Full access
              </div>
            )}

            <h3 className="font-display text-2xl font-bold text-[var(--deep-brown)] mb-1">{tier.name}</h3>
            <p className="text-[13px] text-[var(--dust)] mb-6">{tier.subtitle}</p>

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
              href={isSignedIn ? "/hub" : tier.href}
              className={`w-full flex items-center justify-center gap-2 px-5 py-3.5 rounded-xl text-[13px] font-medium transition-all
                hover:scale-[1.02] active:scale-[0.98]
                ${tier.featured
                  ? "bg-[var(--deep-brown)] text-[var(--warm-white)] hover:opacity-90 shadow-md"
                  : "bg-[var(--deep-brown)] text-[var(--warm-white)] hover:opacity-85 shadow-sm"
                }`}
            >
              {isSignedIn ? "Go to Dashboard" : tier.cta}
              <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        ))}
      </div>
    </section>
  )
}

export function NewsSection() {
  const items = [
    {
      date: "Jun 2026",
      title: "Health MVP: Apple Health & Samsung sync",
      excerpt: "Walk and run data now flows into Personal OS with hourly AI snapshots and daily rollups.",
    },
    {
      date: "May 2026",
      title: "BYOK & Ollama support",
      excerpt: "Run Gemma locally with minimal configuration — your keys, your models, your machine.",
    },
    {
      date: "Coming soon",
      title: "Community skills marketplace",
      excerpt: "Install pillar extensions built by others, the same way you add skills to Claude or ChatGPT.",
    },
  ]

  return (
    <section id="news" className="px-5 py-24 max-w-4xl mx-auto scroll-mt-28 border-t border-[var(--border-subtle)]">
      <div className="text-center mb-14 saas-scroll-reveal">
        <span className="text-[11px] uppercase tracking-[0.15em] text-[var(--amber)] font-semibold mb-4 block">
          News
        </span>
        <h2 className="font-display text-4xl md:text-5xl font-bold text-[var(--deep-brown)]">
          What we&apos;re building
        </h2>
      </div>

      <div className="space-y-6">
        {items.map((item) => (
          <article
            key={item.title}
            className="bg-[var(--warm-white)] rounded-2xl p-6 border border-[var(--border-subtle)] saas-scroll-reveal"
          >
            <time className="text-[11px] uppercase tracking-[0.12em] text-[var(--amber)] font-semibold">
              {item.date}
            </time>
            <h3 className="font-display text-xl font-bold text-[var(--deep-brown)] mt-2 mb-2">
              {item.title}
            </h3>
            <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed">{item.excerpt}</p>
          </article>
        ))}
      </div>
    </section>
  )
}
