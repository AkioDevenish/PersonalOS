# Forklore

An iOS food app that reads Apple Health and suggests what to eat next, with a chat
assistant called Pitchfork and paid consultations with nutritionists.

The repository holds the app, its Convex backend, and a small Next.js site that
serves the privacy policy and terms.

## What's in the app

Pages are picked from a sidebar opened by the glass menu button at the top left.

- **Meals**: today's glucose, carbs, sleep and activity, a country to cook in, and a
  suggestion for the next meal. Suggestions are written on the phone with Apple's
  Foundation Models; on a phone without Apple Intelligence the button asks Pitchfork
  instead. Each country's dish list is written from its Wikipedia cuisine article,
  plus people's votes.
- **Pitchfork**: the chat assistant, by text, voice, photo or file. Replies come from
  Claude through `convex/health/pitchfork.ts`, which can look up the person's own synced
  health history. Chats are saved on the phone only.
- **Read**: articles, six built in plus ones practitioners write. A review team
  verifies practitioners' articles before they're published.
- **Experts**: a directory of nutritionists and other practitioners, with chat, video
  calls over WebRTC, and consultations paid by web checkout (Stripe or WAM).
  Practitioners apply from Profile, then get a practice page, articles and payouts.
- **Profile**: account details, notifications, privacy and terms, log out and account
  deletion.

Apple Health samples sync to Convex incrementally in the background. App Store
subscriptions and one-off purchases are verified on the server, but the paywall is
off for now (`Paywall.enabled` in `ios/Forklore/Store.swift`).

The code still uses the working name Personal OS in places (the `personalos://`
sign-in scheme, the legal pages).

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
- **App Store**: `APPLE_IAP_ENVIRONMENT` (`sandbox` by default, or `production`), `APPLE_ROOT_CERTS`
  (Apple's root certificates, base64 DER, separated by `|`), and `APPLE_APP_ID` (the app's numeric
  Apple ID from App Store Connect, required for `production`). `xcode` also needs
  `APPLE_IAP_ALLOW_UNSIGNED=true`, because Xcode's local purchases are not signed by Apple.
  Point App Store Connect's Server Notifications (version 2) at
  `https://<deployment>.convex.site/appstore/notifications` so renewals, expiries and refunds
  reach the backend.
- **Push (APNs)**: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_P8`, and `APNS_ENVIRONMENT` (`production`
  or `sandbox`; nothing is sent until it is set)
- **Payouts**: `STRIPE_SECRET_KEY`, `PLATFORM_FEE_PERCENT`
- **Consultation payments (WAM)**: `WAM_API_KEY`, `WAM_BUSINESS_ID`, `WAM_ENVIRONMENT`
- **Calls**: `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL` (optional; STUN is used without them)
- **Roles**: `NUTRITIONIST_IDS`, `ARTICLE_REVIEWER_IDS`
- **AI**: `ANTHROPIC_API_KEY` for Pitchfork and the dish lists. For cheap testing on the dev
  deployment only, `PITCHFORK_PROVIDER=gemini` with `GEMINI_API_KEY` (and optionally
  `GEMINI_MODEL`, default `gemini-2.5-flash`) answers Pitchfork with Gemini's free tier instead.
  The code refuses it anywhere but dev.
