// Marketing copy shared by the standalone pages (/about, /how-it-works,
// /pricing, /news). Kept out of story-client so the story stays scroll-only.

export const PILLARS = [
  {
    numeral: "I",
    title: "Health",
    body: "Pulls from Apple Health or Samsung Health — walks, runs, glucose, sleep, and more. Daily, weekly, and monthly insights as if you had a data scientist, physician, trainer, and dietitian on call.",
  },
  {
    numeral: "II",
    title: "Education",
    body: "Tracks learning goals, courses, and skill growth. Surfaces what to study next based on your pace and gaps — without juggling another app dashboard every morning.",
  },
  {
    numeral: "III",
    title: "Business & Finances",
    body: "Unifies deals, cash flow, and follow-ups. AI watches patterns across accounts and nudges you before opportunities slip — one lens instead of ten tabs.",
  },
  {
    numeral: "IV",
    title: "Relationships",
    body: "Remembers who matters, when you last connected, and what's due. Gentle prompts to show up for people — integrated, not another contact manager to open.",
  },
  {
    numeral: "V",
    title: "Purpose",
    body: "Long-horizon goals, reflection, and alignment. Connects the other pillars so progress in health and work feeds meaning — not isolated metrics.",
  },
  {
    numeral: "VI",
    title: "Your sixth pillar",
    body: "The system is self-extending. Community-built skills — like ChatGPT or Claude extensions — can be installed into your Personal OS. Someone ships a finance pillar; you add it in one step.",
  },
]

export const STEPS = [
  {
    numeral: "01",
    title: "Connect quietly",
    body: "Link Apple Health, Samsung Health, email, calendars, and accounts. Data flows in the background — no daily ritual of opening each app.",
  },
  {
    numeral: "02",
    title: "AI reads the whole picture",
    body: "Local or cloud models analyze patterns across pillars. Health gets hourly snapshots; finances get weekly rollups — whatever the domain needs.",
  },
  {
    numeral: "03",
    title: "You get one briefing",
    body: "Improvement areas, meal ideas, follow-up reminders, and alerts land in one hub. Configure almost nothing: BYOK or use Gemma via Ollama to start.",
  },
]

/** Annual is billed at 10x the monthly rate — two months free. */
export const ANNUAL_MONTHS_CHARGED = 10

export const TIERS = [
  {
    name: "Free",
    subtitle: "Get started with zero cost",
    monthly: 0,
    featured: false,
    features: [
      "Connect Gemma via Ollama or any free local model",
      "Bring your own API keys (BYOK)",
      "Health pillar: walks, runs, daily & weekly insights",
      "Limited integrations & community skills browse",
      "Local-first data on your machine",
    ],
    cta: "Start Free",
  },
  {
    name: "Pro",
    subtitle: "Full platform + premium models",
    monthly: 12,
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
  },
  {
    name: "Enterprise",
    subtitle: "Custom compute & dedicated team support",
    monthly: 49,
    featured: false,
    features: [
      "Everything in Pro",
      "Dedicated server sidecar & model cluster",
      "Custom security policies & compliance",
      "Team workspace & shared agent tools",
      "24/7 dedicated support",
    ],
    cta: "Contact Enterprise",
  },
]

export const PRINCIPLES = [
  {
    numeral: "I",
    title: "Local first, always optional",
    body: "Your ledger runs on your machine by default. Cloud models are something you opt into with your own key — never a condition of using the system.",
  },
  {
    numeral: "II",
    title: "One surface, not another dashboard",
    body: "Every feature has to earn its place by removing a destination, not adding one. If it makes you open something new each morning, it isn't finished.",
  },
  {
    numeral: "III",
    title: "Guidance over charts",
    body: "A graph asks you to interpret. A briefing tells you what changed and what to do. We ship the second and keep the first available underneath.",
  },
  {
    numeral: "IV",
    title: "Extensible by anyone",
    body: "Pillars are a format, not a fixed set. Community skills install the same way extensions do for Claude or ChatGPT — and yours can be one of them.",
  },
]

export const MILESTONES = [
  {
    when: "May 2026",
    title: "BYOK & Ollama support",
    body: "Local models via Ollama, plus your own keys for hosted frontier models.",
    done: true,
  },
  {
    when: "Jun 2026",
    title: "Health pillar, first light",
    body: "Apple Health and Samsung Health sync with hourly snapshots and daily rollups.",
    done: true,
  },
  {
    when: "In progress",
    title: "Business & finances pillar",
    body: "Cash flow, deals, and follow-ups unified with pattern alerts across accounts.",
    done: false,
  },
  {
    when: "Next",
    title: "Community skills marketplace",
    body: "Install pillar extensions built by others in a single step.",
    done: false,
  },
]

export const INTEGRATIONS = [
  { title: "Apple Health", body: "Walks, runs, sleep, glucose, heart rate, workouts." },
  { title: "Samsung Health", body: "The same signals from the Android side of the fence." },
  { title: "Mail & calendar", body: "Commitments, follow-ups, and where the hours actually went." },
  { title: "Banking & accounts", body: "Cash flow and spend patterns, read-only by design." },
  { title: "CRM & deals", body: "Pipeline movement, so nudges arrive before something slips." },
  { title: "Your own sources", body: "Anything a community skill can reach — the format is open." },
]

export const HOW_FAQ = [
  {
    q: "Where does my data actually live?",
    a: "On your machine by default. Personal OS keeps a local store and runs local models against it through Ollama. Nothing leaves unless you connect a hosted model with your own key, and you can see exactly which pillars are configured to use one.",
  },
  {
    q: "Do I need an API key to start?",
    a: "No. Start free with Gemma via Ollama and everything on the Free tier works without any key at all. Bring your own key when you want frontier-model quality, or move to Pro for hosted access without managing keys yourself.",
  },
  {
    q: "How often does it look at my data?",
    a: "It depends on the domain, which is the point. Health takes hourly snapshots because signals move that fast. Finances roll up weekly. Relationships surface when something is actually due rather than on a schedule.",
  },
  {
    q: "What happens if I stop paying?",
    a: "You fall back to the Free tier and your local data stays exactly where it is — on your machine. Nothing is held hostage; hosted model access is what you lose, not your ledger.",
  },
  {
    q: "Can I build my own pillar?",
    a: "Yes — that's the sixth pillar. Skills are installable extensions in the same spirit as Claude or ChatGPT extensions. The marketplace for sharing them is the next milestone on the roadmap.",
  },
]

export const PRICING_FAQ = [
  {
    q: "What does annual billing actually save?",
    a: "Two months. Annual plans are billed at ten times the monthly rate, so Pro comes to $120 a year instead of $144. You can switch between monthly and annual at any time and the change is prorated.",
  },
  {
    q: "Is the Free tier a trial?",
    a: "No. It's permanent and it's genuinely useful — local models, your own keys, the health pillar, and local-first storage. It exists because the system should be worth running before you pay for it.",
  },
  {
    q: "Do I pay for model usage on top?",
    a: "On Free and on BYOK you pay your model provider directly, so costs are whatever your own key incurs. Pro includes hosted access to Claude, ChatGPT, and other models with no separate bill.",
  },
  {
    q: "What makes Enterprise different?",
    a: "A dedicated server sidecar and model cluster rather than shared hosted capacity, plus custom security policies, a team workspace with shared agent tools, and 24/7 support.",
  },
]

export const COMPARE_ROWS: {
  feature: string
  free: string | boolean
  pro: string | boolean
  enterprise: string | boolean
}[] = [
  { feature: "Local models via Ollama", free: true, pro: true, enterprise: true },
  { feature: "Bring your own API keys", free: true, pro: true, enterprise: true },
  { feature: "Local-first data storage", free: true, pro: true, enterprise: true },
  { feature: "Health pillar", free: "Basic", pro: "Advanced", enterprise: "Advanced" },
  { feature: "Pillars included", free: "1", pro: "All 5", enterprise: "All 5" },
  { feature: "Hosted frontier models", free: false, pro: true, enterprise: true },
  { feature: "Install community skills", free: "Browse only", pro: true, enterprise: true },
  { feature: "Publish community skills", free: false, pro: true, enterprise: true },
  { feature: "Glucose-aware meal recs", free: false, pro: true, enterprise: true },
  { feature: "Dedicated model cluster", free: false, pro: false, enterprise: true },
  { feature: "Team workspace", free: false, pro: false, enterprise: true },
  { feature: "Support", free: "Community", pro: "Priority", enterprise: "24/7 dedicated" },
]

export type Post = {
  slug: string
  date: string
  dateISO: string | null
  title: string
  excerpt: string
  body: ({ type: "p" | "h2"; text: string } | { type: "ul"; items: string[] })[]
}

/** Newest first — the index and the [slug] route both read this order. */
export const POSTS: Post[] = [
  {
    slug: "health-mvp-apple-samsung-sync",
    date: "Jun 2026",
    dateISO: "2026-06-01",
    title: "Health MVP: Apple Health & Samsung sync",
    excerpt:
      "Walk and run data now flows into Personal OS with hourly AI snapshots and daily rollups.",
    body: [
      {
        type: "p",
        text: "The health pillar is the first one to reach a state we're willing to call finished enough to depend on. Apple Health and Samsung Health now sync into Personal OS directly, and the analysis runs without you opening anything.",
      },
      { type: "h2", text: "What syncs" },
      {
        type: "p",
        text: "Walks and runs were the first targets because they're the signals people check most and interpret least. Distance, pace, heart rate, and route data all land in the local store.",
      },
      {
        type: "ul",
        items: [
          "Walks and runs, with pace and heart-rate series",
          "Sleep stages and duration",
          "Glucose, where a compatible monitor is connected",
          "Workouts logged in either app",
        ],
      },
      { type: "h2", text: "Hourly snapshots, daily rollups" },
      {
        type: "p",
        text: "Health signals move faster than the rest of your ledger, so the pillar samples them hourly rather than waiting for a nightly batch. Each snapshot is cheap; the daily rollup is where the model actually reasons across the day and writes the briefing you read.",
      },
      {
        type: "p",
        text: "The practical effect is that a bad night's sleep shows up in the morning briefing as a suggestion, not as a chart you have to go and find.",
      },
      { type: "h2", text: "Running it locally" },
      {
        type: "p",
        text: "Everything described here works on the Free tier with Gemma through Ollama. Hosted models produce better prose in the briefings, but the analysis itself does not depend on them.",
      },
    ],
  },
  {
    slug: "byok-and-ollama-support",
    date: "May 2026",
    dateISO: "2026-05-01",
    title: "BYOK & Ollama support",
    excerpt:
      "Run Gemma locally with minimal configuration — your keys, your models, your machine.",
    body: [
      {
        type: "p",
        text: "Personal OS now runs entirely on models you control. Point it at a local Ollama instance, or supply your own API key for a hosted provider. Both paths are first-class; neither is a degraded mode.",
      },
      { type: "h2", text: "Why local first" },
      {
        type: "p",
        text: "A system that reads your health data, your mail, and your finances is holding the most sensitive picture of you that exists anywhere. The default posture for that has to be local. Cloud inference is a choice you make per pillar, with your own key, not a condition of entry.",
      },
      { type: "h2", text: "Setup" },
      {
        type: "p",
        text: "Install Ollama, pull Gemma, and Personal OS will find it. There is no configuration file to write and no model registry to populate. If you'd rather use a hosted model, paste a key and pick which pillars are allowed to use it.",
      },
      {
        type: "p",
        text: "The tradeoff is honest: local models are slower and their briefings read more plainly. For most of what the system does — noticing a pattern, remembering a commitment, flagging a change — that's entirely sufficient.",
      },
    ],
  },
  {
    slug: "community-skills-marketplace",
    date: "Coming soon",
    dateISO: null,
    title: "Community skills marketplace",
    excerpt:
      "Install pillar extensions built by others, the same way you add skills to Claude or ChatGPT.",
    body: [
      {
        type: "p",
        text: "The five pillars that ship with Personal OS are a starting set, not a boundary. The sixth pillar is whatever you or someone else builds — and the marketplace is how that gets shared.",
      },
      { type: "h2", text: "What a skill is" },
      {
        type: "p",
        text: "A skill declares what data it wants to read, what it computes, and what it contributes to your briefing. It installs in one step and can be removed just as cleanly. Nothing about the format is privileged to us: the built-in pillars use the same interface community skills will.",
      },
      { type: "h2", text: "Where this is" },
      {
        type: "p",
        text: "The skill format is settled and the built-in pillars have been migrated onto it. What's left is the distribution side — publishing, versioning, and the permission review that has to sit in front of anything reading a ledger this personal. That work is underway; this post will be updated when there's a date worth publishing.",
      },
    ],
  },
]
