/**
 * What an article must be before a person is asked to review it.
 *
 * Plain functions with no database and no identity, so the whole of the
 * automatic check can be tested on its own and run identically on every save
 * and every submission. The server is the only place this runs: a check the
 * app performs is a check an edited request skips.
 *
 * Two kinds of finding, and the difference is the point.
 *
 * Errors block submission. They are things no reviewer should spend time on:
 * a missing summary, a body too short to be an article, a link. Links are the
 * strictest rule here because they are how a health platform ends up sending
 * readers to a supplement shop, and there is no reviewer workload at which
 * checking every destination is sustainable.
 *
 * Flags do not block. A sentence containing "cure" may be a warning against
 * miracle cures. Deciding that is judgement, so it is put in front of the
 * reviewer, highlighted, rather than decided by a regular expression.
 */

export const CATEGORIES = ["Your cycle", "Sleep & recovery", "Moving", "Eating", "Mind"] as const

/** The pictures an article may use: symbols and colours that are known to render. */
export const SYMBOLS = [
  "circle.dotted", "calendar.badge.clock", "heart", "moon.stars", "figure.walk",
  "figure.walk.motion", "leaf", "fork.knife", "brain.head.profile", "sparkles",
  "drop", "sun.max", "bed.double", "lungs", "stethoscope",
] as const

export const COLOURS = [
  "9E566F", "7A4E8C", "A0322E", "2F4A7A", "4E7A45", "3F6E7A", "8A6A2F", "5A5F6B",
] as const

export const LIMITS = {
  title: { min: 8, max: 90 },
  summary: { min: 30, max: 220 },
  paragraphs: { min: 3, max: 40 },
  words: { min: 120, max: 2500 },
  /** Refused even on a draft save, so nobody can park megabytes in a row. */
  bodyCharacters: 30000,
} as const

export type ArticleInput = {
  title: string
  category: string
  summary: string
  body: string
  symbol: string
  colour: string
}

export type Findings = {
  errors: string[]
  flags: string[]
  paragraphs: string[]
  words: number
  minutes: number
}

/** Paragraphs are separated by a blank line, the way anyone types them. */
export function paragraphsOf(body: string): string[] {
  return body
    .replace(/\r\n/g, "\n")
    .split(/\n\s*\n/)
    .map((p) => p.replace(/\s+/g, " ").trim())
    .filter(Boolean)
}

const LINK = /\bhttps?:\/\/|\bwww\.|\b[a-z0-9-]+\.(com|org|net|io|co|shop|store|info|health|biz|app|ly)\b/i
const EMAIL = /[^\s@]+@[^\s@]+\.[a-z]{2,}/i
const PHONE_RUN = /\+?\d[\d\s().-]{6,}\d/g

/**
 * A run of digits and phone punctuation holding at least nine digits.
 *
 * Counted rather than matched by shape, because "2019 - 2023" and "7 to 9
 * hours, 10 - 12" are the same characters as a phone number to a pattern and
 * an article about research years should not be refused for it.
 */
function containsPhone(text: string): boolean {
  return (text.match(PHONE_RUN) ?? []).some((run) => (run.match(/\d/g) ?? []).length >= 9)
}

const SOFT: Array<[RegExp, string]> = [
  [/\b(cure[sd]?|curing)\b/i, "Uses the word cure"],
  [/\b(guarantee[sd]?|100\s?%|never fails|proven to)\b/i, "Makes an absolute promise"],
  [/\b(miracle|detox|cleanse)\b/i, "Uses wellness-marketing language"],
  [/\b\d+(\.\d+)?\s?(mg|mcg|µg|ml|iu|units)\b/i, "Mentions a dose"],
  [/\bstop (taking )?(your )?(medication|medicine|meds|insulin|pills|treatment)\b/i, "Talks about stopping treatment"],
  [/\b(instead of|rather than|no need for|don't need) (a |your )?(doctor|gp|clinician|medication|treatment)\b/i, "Suggests skipping medical care"],
  [/\b(pregnan|abortion|miscarriage|suicid|self-harm|overdose)\w*/i, "Covers a sensitive subject"],
]

export function check(input: ArticleInput): Findings {
  const errors: string[] = []
  const flags: string[] = []

  const title = input.title.trim()
  const summary = input.summary.trim()
  const paragraphs = paragraphsOf(input.body)
  const words = paragraphs.join(" ").split(/\s+/).filter(Boolean).length

  if (title.length < LIMITS.title.min) errors.push(`The title needs at least ${LIMITS.title.min} characters`)
  if (title.length > LIMITS.title.max) errors.push(`The title can be at most ${LIMITS.title.max} characters`)
  if (!(CATEGORIES as readonly string[]).includes(input.category)) errors.push("Choose one of the listed categories")
  if (summary.length < LIMITS.summary.min) errors.push(`The summary needs at least ${LIMITS.summary.min} characters`)
  if (summary.length > LIMITS.summary.max) errors.push(`The summary can be at most ${LIMITS.summary.max} characters`)
  if (paragraphs.length < LIMITS.paragraphs.min) errors.push(`Write at least ${LIMITS.paragraphs.min} paragraphs, separated by a blank line`)
  if (paragraphs.length > LIMITS.paragraphs.max) errors.push(`An article can have at most ${LIMITS.paragraphs.max} paragraphs`)
  if (words < LIMITS.words.min) errors.push(`The article needs at least ${LIMITS.words.min} words; it has ${words}`)
  if (words > LIMITS.words.max) errors.push(`The article can be at most ${LIMITS.words.max} words; it has ${words}`)
  if (!(SYMBOLS as readonly string[]).includes(input.symbol)) errors.push("Choose one of the listed pictures")
  if (!(COLOURS as readonly string[]).includes(input.colour)) errors.push("Choose one of the listed colours")

  const everything = [title, summary, ...paragraphs].join("\n")
  if (LINK.test(everything)) errors.push("Links are not allowed in articles")
  if (EMAIL.test(everything)) errors.push("Email addresses are not allowed in articles")
  if (containsPhone(everything)) errors.push("Phone numbers are not allowed in articles")

  for (const [pattern, flag] of SOFT) {
    if (pattern.test(everything)) flags.push(flag)
  }

  // About 220 words a minute, and never "0 min".
  const minutes = Math.max(1, Math.round(words / 220))
  return { errors, flags, paragraphs, words, minutes }
}
