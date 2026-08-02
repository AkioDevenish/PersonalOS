import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'
import { NextResponse } from 'next/server'

// Personal OS is a phone app; the web is a marketing site plus the API the
// apps talk to. Everything public here, and the only authenticated surface
// left is /api/*, which the apps reach with a Clerk bearer token.
const isPublicRoute = createRouteMatcher([
  '/',
  '/about',
  '/how-it-works',
  '/pricing',
  '/news(.*)',
  '/privacy',
  '/terms',
  '/download',
  // OAuth lands here — providers redirect to a web URL, not into an app
  '/connected',
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/webhooks(.*)',
  // signature-verified server-to-server; no session exists to check
  '/api/health/webhooks(.*)',
  // retired endpoint — public so an old client reads the 410 telling it where
  // to go, instead of an opaque 401 that looks like a credentials problem
  '/api/well-being/ingest',
])

export default clerkMiddleware(async (auth, request) => {
  if (isPublicRoute(request)) return

  const { userId, redirectToSignIn } = await auth()
  if (userId) return

  /**
   * API routes must be rejected as JSON.
   *
   * auth.protect() rewrites an unauthorised request to Clerk's HTML 404 page.
   * For a page that's fine, but a browser fetch then calls res.json() on 17KB
   * of markup and throws "Unexpected end of JSON input" — which points at the
   * caller instead of the real cause, and hides the 401 completely.
   */
  if (request.nextUrl.pathname.startsWith('/api/')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  return redirectToSignIn()
})

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
}
