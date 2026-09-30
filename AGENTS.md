<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# What this repo is

The iOS app (`ios/Forklore`, SwiftUI) and its Convex backend (`convex/`).
The Next.js app in `src/app` only serves the privacy and terms pages; there are
no API routes, and the app talks to Convex directly. See `README.md` for the
feature map.

# Environment Variables

Secrets are Convex deployment env vars (`npx convex env set`), read with
`process.env` inside Convex functions. Nothing is committed; `.env*` is ignored.
The full list is in `README.md` under Configuration. Key groups:

- **Auth:** `JWT_PRIVATE_KEY`, `JWKS`, `CONVEX_SITE_URL`, and optional
  `AUTH_{GOOGLE,FACEBOOK,APPLE}_{ID,SECRET}` pairs
- **App Store / push:** `APPLE_IAP_ENVIRONMENT`, `APPLE_ROOT_CERTS`, `APNS_*`
- **Payments:** `STRIPE_SECRET_KEY`, `PLATFORM_FEE_PERCENT`, `WAM_*`
- **Calls:** `TURN_URL`, `TURN_USERNAME`, `TURN_CREDENTIAL`
- **Roles:** `NUTRITIONIST_IDS`, `ARTICLE_REVIEWER_IDS`

# Codebase Conventions

- **Auth:** `@convex-dev/auth`, configured in `convex/auth.ts` (email and
  password, plus Google, Facebook and Apple when their credentials are set).
  Sign-in redirects may only return to `personalos://`.
- **Who is asking:** Convex functions get the caller from
  `ctx.auth.getUserIdentity()` and key rows by `userIdOf(identity)` from
  `convex/lib/me.ts`. Never take a user id from the client.
- **Health data:** samples live in Convex (`convex/health/samples.ts`), keyed by
  user, provider, metric and time. There is no SQLite.
- **AI:** insights are generated on the phone with Apple's Foundation Models
  (`ios/Forklore/OnDeviceInsights.swift`). The one server model call is
  `convex/health/cuisineAi.ts`, which turns a country's Wikipedia cuisine article
  into a dish list with Claude (`ANTHROPIC_API_KEY`). It sends only the country
  and the article, never user data, and the privacy page says so. Keep it that way.
- **Tests:** `npm test` runs the vitest suites in `convex/**/*.test.ts`.

<!-- convex-ai-start -->

This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read
`convex/_generated/ai/guidelines.md` first** for important guidelines on
how to correctly use Convex APIs and patterns. The file contains rules that
override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running
`npx convex ai-files install`.

<!-- convex-ai-end -->
