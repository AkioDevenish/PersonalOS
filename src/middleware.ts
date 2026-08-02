import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

// Everything the marketing site serves is public; only /hub and friends
// sit behind auth. Keep in sync with NAV_ITEMS in components/layout/nav.ts.
const isPublicRoute = createRouteMatcher([
  '/',
  '/about',
  '/how-it-works',
  '/pricing',
  '/news(.*)',
  '/privacy',
  '/terms',
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/webhooks(.*)',
])

export default clerkMiddleware(async (auth, request) => {
  if (!isPublicRoute(request)) {
    await auth.protect()
  }
})

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
}
