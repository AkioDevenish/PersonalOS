/**
 * The platform's share of a consultation.
 *
 * Its own file, with no Node imports, so the Stripe action and the plain
 * query that reports the percentage can both use exactly this arithmetic
 * rather than each doing its own.
 */

const DEFAULT_PERCENT = 15

/**
 * What the platform keeps, as a percentage.
 *
 * An unset variable and one set to an empty string mean the same thing here,
 * which they do not to `??`: `Number("")` is 0, so a deployment with the
 * variable present but blank was taking no commission at all. A value outside
 * nought to fifty is a typo, and a typo here is somebody's wages.
 */
export function feePercent(): number {
  const raw = (process.env.PLATFORM_FEE_PERCENT ?? "").trim()
  if (raw === "") return DEFAULT_PERCENT
  const parsed = Number(raw)
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 50) return DEFAULT_PERCENT
  return parsed
}

/** The share of an amount, in whole minor units. Never a fraction of a cent. */
export function feeOn(amountMinor: number): number {
  return Math.round((amountMinor * feePercent()) / 100)
}
