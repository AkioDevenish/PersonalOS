"use client"
import { useStored } from "./store"

/** Where they cook, kept in this browser like the phone keeps it (Cuisine.key on iOS). */
export const COUNTRY_KEY = "fl.country"

/** Two-letter codes that name places people don't cook in: groupings and reserved codes. */
const NOT_COUNTRIES = new Set(["EU", "EZ", "UN", "QO", "XA", "XB", "ZZ", "AQ", "BV", "HM", "UM", "TF", "IO", "AC", "CP", "DG", "EA", "IC", "TA", "CQ"])

let all: { code: string; name: string }[] | null = null

/** Every country the browser can name, in the reader's language, A to Z. */
export function countries() {
  if (all) return all
  const names = new Intl.DisplayNames(undefined, { type: "region", fallback: "none" })
  const out: { code: string; name: string }[] = []
  for (let a = 65; a <= 90; a++) {
    for (let b = 65; b <= 90; b++) {
      const code = String.fromCharCode(a, b)
      if (NOT_COUNTRIES.has(code)) continue
      let name: string | undefined
      try {
        name = names.of(code)
      } catch {
        name = undefined
      }
      if (name && name !== code) out.push({ code, name })
    }
  }
  all = out.sort((x, y) => x.name.localeCompare(y.name))
  return all
}

export function countryName(code: string) {
  if (!code) return "Anywhere"
  return countries().find((c) => c.code === code)?.name ?? code
}

/** The browser's own region as the first guess, as the phone uses its own. */
function guess(): string {
  try {
    const region = new Intl.Locale(navigator.language).maximize().region ?? ""
    return /^[A-Z]{2}$/.test(region) ? region : ""
  } catch {
    return ""
  }
}

const UNSET = "?"

export function useCountry(): [string, (code: string) => void] {
  const [stored, set] = useStored<string>(COUNTRY_KEY, UNSET)
  return [stored === UNSET ? guess() : stored, set]
}
