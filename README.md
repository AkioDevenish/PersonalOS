# Forklore

An iOS app for health, food and the rest of a day: it reads Apple Health, writes a
morning briefing on the phone itself, and connects people with nutritionists and
other practitioners for paid consultations.

The repository holds the app, its Convex backend, and a small Next.js site that
serves the privacy policy and terms.

## What's in the app

- **Health**: a morning briefing, a ledger of Apple Health readings, trends,
  insights, goals and cycle tracking. Samples sync to Convex incrementally.
- **Food**: cuisine by country (a written list of dishes plus people's votes) and
  meal readings.
- **Time and money**: simple ledgers for where the day and the money went.
- **Specialists**: a directory of practitioners, consultation calls over
  WebRTC, and payouts to practitioners with a platform fee.
- **Articles**: practitioners write articles, a review team verifies them, and
  readers unlock them with a purchase.
- **Billing**: App Store subscriptions and one-off purchases, verified on the
  server.

AI insights run on the phone with Apple's Foundation Models (Apple Intelligence),
so no health data is sent to a model server.

The code still uses the working name Personal OS in places (the Xcode target,
the `personalos://` sign-in scheme, the legal pages).

## Layout

| Path | What it is |
|------|------------|
| `ios/Forklore/` | The SwiftUI app (iOS 26.5+). Open `ios/Forklore.xcodeproj`. |
| `convex/` | The backend: schema, auth, health ingest, consultations, payouts, articles, billing, push. |
| `convex/*.test.ts` | Backend tests, run with vitest and `convex-test`. |
| `src/app/` | Next.js pages for `/privacy` and `/terms`, plus icons. There is no web app. |
| `scripts/apple-secret.mjs` | Makes the Sign in with Apple client secret from a `.p8` key. |
| `docs/machine-backups/` | Old crontab and launchd files from the Mac setup, kept for reference. |

## Getting started

```bash
npm install
npx convex dev        # runs the backend against your dev deployment
npm test              # backend tests
```

Then open `ios/Forklore.xcodeproj` in Xcode and run on a device. The app
talks straight to Convex; the deployment URL is in
`ios/Forklore/AppConfig.swift`.

`npm run dev` starts the Next.js site if you're working on the legal pages. The
same pages are also served by Convex at `/privacy` and `/terms` on the deployment's
`.convex.site` URL, which is what the app links to.

## Configuration

Secrets live as Convex deployment env vars (`npx convex env set KEY value`), never
in the repo. The backend reads:

- **Auth** (`@convex-dev/auth`): `JWT_PRIVATE_KEY` and `JWKS` (set by `npx @convex-dev/auth`), plus `AUTH_GOOGLE_ID`/`AUTH_GOOGLE_SECRET`,
  `AUTH_FACEBOOK_ID`/`AUTH_FACEBOOK_SECRET`, `AUTH_APPLE_ID`/`AUTH_APPLE_SECRET`. Each social
  provider is enabled only when its pair is set; email and password always work.
- **App Store**: `APPLE_IAP_ENVIRONMENT`, `APPLE_ROOT_CERTS`
- **Push (APNs)**: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_P8`, `APNS_ENVIRONMENT`
- **Payouts**: `STRIPE_SECRET_KEY`, `PLATFORM_FEE_PERCENT`
- **Consultation payments (WAM)**: `WAM_API_KEY`, `WAM_BUSINESS_ID`, `WAM_ENVIRONMENT`
- **Calls**: `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` (optional; STUN is used without them)
- **Roles**: `NUTRITIONIST_IDS`, `ARTICLE_REVIEWER_IDS`
