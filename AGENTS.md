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
- **Data paths:** `HEALTH_DB_PATH`, `MARKETING_DB_PATH`, `ACTIVITY_SYNC_SCRIPT_PATH`, `DS_TRACKER_PATH`

Routes that depend on Ollama/Gemma (music recommendation, marketing generate, nutrition AI) prefer `GEMMA_URL`/`GEMMA_MODEL` over `OLLAMA_*` over inline defaults.

# Codebase Conventions

- **Auth:** Clerk JWT token is passed to Convex via `getToken({ template: 'convex' })`. See `src/lib/convex-client.ts`.
- **API routes:** Use `getRequestActor(request)` from `src/lib/request-actor.ts` for multi-tenant support.
- **Health SQLite:** DB path is resolved via `HEALTH_DB_PATH` env var, then `~/personal_os/Well Being/data/health.db`.
- **Landing page:** Auth-aware; redirects signed-in users to `/hub`.
