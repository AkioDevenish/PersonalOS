const REQUIRED_PROD: string[] = [
  'NEXT_PUBLIC_CONVEX_URL',
  'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY',
  'CLERK_SECRET_KEY',
]

const REQUIRED_ALWAYS: string[] = []

export function validateEnv(): void {
  if (typeof window !== 'undefined') return

  const missing: string[] = []
  for (const key of REQUIRED_ALWAYS) {
    if (!process.env[key]) missing.push(key)
  }

  if (process.env.VERCEL || process.env.NODE_ENV === 'production') {
    for (const key of REQUIRED_PROD) {
      if (!process.env[key]) missing.push(key)
    }
  }

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables:\n  ${missing.join('\n  ')}\n\n` +
        'Set them in .env.local or Vercel project settings.',
    )
  }
}
