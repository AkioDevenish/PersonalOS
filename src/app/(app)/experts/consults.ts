/** The consultations this person started from this browser, newest first. */
export type Started = { id: string; specialistId: string; name: string; topic: string; at: number }
export const CONSULTS_KEY = "fl.consults"
export const NO_CONSULTS: Started[] = []

/** "TT$150.00" from 15000 and "TTD". */
export function money(minor: number, currency: string): string {
  try {
    return new Intl.NumberFormat(undefined, { style: "currency", currency }).format(minor / 100)
  } catch {
    return `${(minor / 100).toFixed(2)} ${currency}`
  }
}

/** "Here now", "Seen today", or nothing worth saying. */
export function presence(lastSeen: number, now: number): string {
  if (!lastSeen) return ""
  const minutes = (now - lastSeen) / 60_000
  if (minutes < 5) return "Here now"
  if (minutes < 60 * 24) return "Seen today"
  if (minutes < 60 * 24 * 7) return "Seen this week"
  return ""
}
