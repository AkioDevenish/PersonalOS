/** The platform's share of a consultation. */

const DEFAULT_PERCENT = 15

/** What the platform keeps, as a percentage. */
export function feePercent(): number {
  const raw = (process.env.PLATFORM_FEE_PERCENT ?? "").trim()
  if (raw === "") return DEFAULT_PERCENT
  const parsed = Number(raw)
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 50) return DEFAULT_PERCENT
  return parsed
}

/** The share of an amount, in whole minor units. */
export function feeOn(amountMinor: number): number {
  return Math.round((amountMinor * feePercent()) / 100)
}
