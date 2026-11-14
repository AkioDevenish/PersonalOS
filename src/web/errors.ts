/** A Convex error as one plain sentence for the page, without the server's stack framing. */
export function messageOf(error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error)
  // "[CONVEX M(users:setName)] [Request ID: …] Server Error\nUncaught Error: That is longer than a name\n    at …"
  const uncaught = raw.match(/Uncaught Error: ([^\n]+)/)
  if (uncaught) return uncaught[1].trim()
  if (/InvalidSecret|InvalidAccountId/.test(raw)) return "That email and password don't match."
  if (/Server Error/.test(raw)) return "Something went wrong. Try again in a moment."
  return raw
}
