import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'
import { NextResponse } from 'next/server'

// There is no website. The only pages are the legal documents the app stores
// require a public URL for; everything else here is the API the phone apps
// call with a Clerk bearer token.
const isPublicRoute = createRouteMatcher([
  '/privacy',
  '/terms',
  '/api/webhooks(.*)',
  // signature-verified server-to-server; no session exists to check
  '/api/health/webhooks(.*)',
  // provider browser redirect — arrives with no session; identity comes from
  // the HMAC-signed state parameter, verified inside the route
  '/api/health/oauth/(.*)/callback',
  // retired endpoint — public so an old client reads the 410 telling it where
  // to go, instead of an opaque 401 that looks like a credentials problem
  '/api/well-being/ingest',
])

export default clerkMiddleware(async (auth, request) => {
  if (isPublicRoute(request)) return

  const { userId } = await auth()
  if (userId) return

  /**
   * API routes must be rejected as JSON — a client fetch calling res.json()
   * on an HTML error page throws "Unexpected end of JSON input" and buries
   * the real 401.
   */
  if (request.nextUrl.pathname.startsWith('/api/')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // No protected pages exist any more; let anything else fall through to 404.
  return
})

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
}
