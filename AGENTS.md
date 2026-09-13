<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Environment Variables

All env vars are documented in `.env.example`. Key groups:

- **Auth:** `CLERK_SECRET_KEY`, `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_FRONTEND_API_URL`
- **Convex:** `NEXT_PUBLIC_CONVEX_URL`, `CONVEX_DEPLOYMENT_KEY`
- **Auth mode:** `PERSONAL_OS_AUTH_MODE` (`local`|`saas`), `PERSONAL_OS_LOCAL_USER_ID`, `PERSONAL_OS_LOCAL_WORKSPACE_ID`
- **AI:** `GEMMA_URL`/`GEMMA_MODEL`, `OLLAMA_URL`/`OLLAMA_MODEL` (aliases)
- **Data paths:** `HEALTH_DB_PATH`

The two routes that reach a local model, `well-being/analyze` and `well-being/nutrition-ai`, prefer `GEMMA_URL`/`GEMMA_MODEL` over `OLLAMA_*` over inline defaults.

# Codebase Conventions

- **Auth:** Clerk JWT token is passed to Convex via `getToken({ template: 'convex' })`. See `src/lib/convex-client.ts`.
- **API routes:** Use `getRequestActor(request)` from `src/lib/request-actor.ts` for multi-tenant support.
- **Health SQLite:** DB path is resolved via `HEALTH_DB_PATH` env var, then `~/personal_os/Well Being/data/health.db`.
- **No web UI:** this is an API surface for the iOS app, plus the privacy and
  terms pages. Every route here has a caller in `ios/PersonalOSHealth`; the
  ledgers, the directory and the consultation both reach Convex directly.

<!-- convex-ai-start -->

This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read
`convex/_generated/ai/guidelines.md` first** for important guidelines on
how to correctly use Convex APIs and patterns. The file contains rules that
override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running
`npx convex ai-files install`.

<!-- convex-ai-end -->
