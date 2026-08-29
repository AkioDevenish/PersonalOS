# Personal OS — project context

A handoff document. Written to bring a model or a new developer up to speed on
what exists, how it is put together, and which parts are load-bearing. It
describes the state of the repository, not a plan.

---

## What the product is

An iPhone app that reads a person's health data and writes them a daily
briefing about it. The sign-in screen says "Time well spent."

The design metaphor is a paper ledger you record your days into, and it runs
through everything: a linen ground, ink for anything that speaks, one amber
accent used as punctuation, a printed serif (Cormorant Garamond) with a
tracked sans (Jost) for labels. The vocabulary follows — days are *kept*, a
good night's sleep *opens in credit*, goals are *still owing*.

Almost all of the product lives in the iPhone app. The server exists to hold
credentials, talk to hosted models, and broker what a phone cannot do alone.

---

## Repository layout

Everything below is relative to `web/` unless stated.

```
ios/PersonalOSHealth/     the iPhone app (SwiftUI, ~37 files) — where the product is
src/app/api/              Next.js API routes — thin brokers, no product logic
convex/                   database schema and server functions
src/lib/                  server helpers: AI providers, Convex client, health db, auth
```

The web app has **no dashboard**. `src/app` contains only `/privacy` and
`/terms`; every other page was removed when the product became an iOS app. Do
not assume a web UI exists.

- Bundle id: `ADEVSTUDIO.PersonalOSHealth`
- iOS deployment target: **26.5** — every modern API is available, do not add
  availability guards for anything below it
- Auth: Clerk. The phone sends a Clerk JWT; routes exchange it for a Convex
  client via `getToken({ template: 'convex' })`
- Backend: Convex (`astute-ant-253`)

---

## The iPhone app

### Foundations

| File | What it holds |
|---|---|
| `Theme.swift` | Colours, fonts, and the shared components: `Kicker`, `SectionRule`, `Plate`, `Ornament`, `Rule` |
| `Motion.swift` | The animation vocabulary — four springs, the press style, `flowIn`, `PillPicker`, `Composing`, `TypedText` |
| `MetricCatalog.swift` | **The single source of truth for every metric** |
| `Emphasis.swift` | Sets measurement names and figures apart inside prose |
| `HealthKitManager.swift` | Reads HealthKit; produces `HealthSnapshot` (one day of readings) |

**`MetricCatalog.swift` is the most important file in the app.** Nineteen
metrics, each defined once with its label, unit, precision, prose name, group,
whether it accumulates, which way a goal on it points, and how its glyph
animates. The grid, the charts, the metric picker, the briefing prose and the
goals screen all read from it. Adding a metric there makes it appear
everywhere; there is no second list to update.

### Screens

| File | Screen |
|---|---|
| `RootView.swift` | Tab bar (Health, Settings), routing, the side drawer host |
| `HealthView.swift` | Home: headline, mood, briefing excerpt, two large figures, metric groups |
| `Briefing.swift` / `BriefingView.swift` | The composer (model) and the full briefing screen (view) |
| `TrendsView.swift` | "Records" — any metric over time, or two compared with Pearson's r |
| `InsightsView.swift` | Two screens: `NutritionView` (meals) and `ExpertsView` (specialists) |
| `ConsultView.swift` | Asking a human nutritionist |
| `GoalsView.swift` (in `Goals.swift`) | Setting targets |
| `ConnectionsView.swift` | Settings: account, sources, plan, goals, model, sync |
| `LedgerDrawer.swift` | The side drawer: Records, Nutrition, Specialists, Goals |

### Things that are easy to get wrong

- **`Briefing.swift` is a pure model.** It takes snapshots and returns English.
  It has no SwiftUI dependency beyond Foundation and is deliberately testable
  by compiling it on a Mac with a stub `HealthSnapshot`. Keep it that way.
- **No em dashes anywhere the app speaks.** Not in UI strings, not in prompts,
  and model output is stripped of them on arrival in `MealReading.clean`.
- **Emphasis is read out of sentences, not marked up at the source.** The
  composer emits plain text; `Emphasis.swift` finds metric names and figures.
- **The bundled serif has no bold.** Both faces are cut from the Light master
  (400 and 500), so weight alone is invisible. Emphasis is carried by the
  Medium cut *plus* a size step *plus* colour (ink for names, amber for
  figures). Real bold would mean shipping a heavier Cormorant.
- **Almost no hairline rules survive.** They were removed deliberately; space
  carries the structure. `SectionRule` is a bare tracked-caps label despite the
  name. Two rules remain: above the tab bar, and the sign-in flourish.
- **`.offset` moves what you see, not what the layout thinks is there.**
  Anything that catches a touch must be applied *before* an offset. This
  already caused one bug where the drawer swallowed its own taps.

---

## Intelligence

Two engines behind one interface, chosen in Settings → Model and keys.

**On-device (default).** Apple's ~3B foundation model via `FoundationModels`.
No key, no network, no data leaving the phone. `OnDeviceInsights.swift` holds
the availability checks, the error vocabulary, and `InsightPrompts` — every
prompt the app sends.

**Hosted.** Anthropic, OpenAI, Google, Moonshot, DeepSeek, xAI, Groq, Mistral,
or a local Ollama. The user supplies a key; it is stored masked and never
returned. `src/lib/ai/providers.ts` is the catalogue; `generateForUser` in
`src/lib/ai/user-model.ts` is the entry point.

Prompt design that is load-bearing and should not be casually undone:

- **The four specialists each get their own columns, question and worked
  example.** They previously shared one prompt with only the persona line
  changed, and returned four near-identical reports.
- **Worked examples belong to a fictional other person** and use metrics the
  real table will not contain, because an earlier version was copied back
  verbatim as the model's first observation.
- **`canReport` refuses before asking** when the data cannot support the
  question. A small model handed two days of steps and asked for three
  observations will invent the missing half — it reported stair speeds that
  appeared nowhere in the input.
- **Meal prompts name the country twice** and are handed an explicit dish
  list, because recalling a country's everyday food is the hard version of the
  task and a small model answers it by inventing plausible names.

---

## Data

### Convex tables

```
health_samples, health_records, health_metric_sources    readings
health_connections, health_oauth_tokens                  wearables
ai_keys, ai_preferences, ai_reports                      intelligence
entitlements, ai_credit_ledger                           billing
consults, consult_messages, nutritionists                asking a human
cuisine_dishes                                           the shared dish list
contacts, interactions, posts, projects, activity_tracking   dormant, see below
```

Two tables are **not scoped to a single user**, which is unusual here and
deliberate:

- **`cuisine_dishes`** — what people in a country say they eat. One row per
  person per dish, so the vote *is* the row: it can be audited, undone, and
  cannot be run up twice by one person. A dish enters the model's vocabulary
  for a country at `CANON_VOTES` (currently 3, meant to rise). Your own
  suggestions count for you immediately.
- **`nutritionists`** — professional profiles. Who *may* answer is an
  allowlist of Clerk ids in the Convex env var `NUTRITIONIST_IDS`; the row only
  says who they are. Being allowlisted does not put you on the list — that
  needs a profile marked active.

### Billing

StoreKit subscriptions and credits. `entitlements` holds the balance;
`ai_credit_ledger` records every movement so a balance can be explained.
Consultations are charged **in Convex before the consultation is written** — a
price the client can decline to charge is not a price, and an unpaid
consultation that exists is worse than one refused.

---

## What is live, what is not

**Working:** HealthKit reads and sync, the briefing (daily/weekly/monthly),
Records, meals, the four specialists, goals, the shared dish list, Oura/Whoop/
Fitbit OAuth and pull, subscriptions and credits, local notifications when a
reading lands.

**Built but unstaffed:** the nutritionist consult. It needs `NUTRITIONIST_IDS`
set in the Convex dashboard and a profile per person via `upsertProfile`.
Until then the list is empty and the screen says so plainly rather than
pretending. There is no admin UI for writing profiles. **Nothing verifies
credentials** — the profile says whatever the person types, which is fine
while the author is testing and not fine once a stranger pays for advice.

**Dormant but intact:** Business, Marketing and Data Science. Their screens
(`PillarViews.swift`), client (`PillarClient.swift`), routes (`/api/pillars`,
`/api/business/*`, `/api/marketing/*`, `/api/data-science/*`) and Convex
modules all still work. They were removed from the tab bar, not deleted.
Restoring one is adding a case to `Tab` and a line to the switch.

---

## Constraints worth knowing before proposing anything

- **The app is signed with a free Apple account.** Provisioning profiles last
  **7 days**; the app stops launching when one lapses and needs a rebuild and
  reinstall. A paid Developer Program membership fixes this and is also what
  Sign in with Apple and TestFlight require. Until then the app cannot be put
  on anyone else's phone — which matters, because the dish list and the
  consult are features whose whole point is other people.
- **On-device is the default engine and it is a ~3B model.** It follows a few
  concrete rules well and many abstract ones badly. Prompts here are written
  for that, and instructions like "never use #, *, or bullet characters" exist
  because vaguer versions were ignored.
- **The briefing must work offline.** Goals are stored on the phone rather
  than in Convex for this reason.
- **Health data leaving the phone is the most consequential thing the app
  does.** The consult shows the readings before they are sent and stores what
  was consented to, rather than re-reading live numbers later.

---

## Conventions

- **Comments explain why, not what.** The codebase is heavily commented in a
  particular register: what was tried, what broke, and why the current shape
  won. Match it. A comment restating the code is worse than none.
- Metrics get added to `MetricCatalog.swift`, never to a view.
- Motion comes from `Theme.Motion`; do not invent a spring in a view.
- Reduce Motion is honoured centrally in `Theme.Motion.honour`.
- Server routes stay thin. Rules about who may read or write what live in
  Convex, where the client cannot skip them.
- `AGENTS.md` notes that this Next.js version has breaking changes from what a
  model may remember; read `node_modules/next/dist/docs/` before writing
  route code.
