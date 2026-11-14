import { countryName } from "./country"

export type Line = { who: "you" | "assistant"; text: string; looked?: string[] }
export type Chat = { id: string; title: string; lines: Line[]; updated: number }

/** Chats live in this browser only, as they live on the phone only. */
export const CHATS_KEY = "fl.chats"
export const CURRENT_KEY = "fl.chat.current"
/** Kept per browser, newest first. */
export const MAX_CHATS = 50

export const NO_CHATS: Chat[] = []

/**
 * What the page tells Pitchfork about today. The phone sends today's Apple Health numbers here;
 * a browser has none of its own, so it says so and Pitchfork reads synced history with its tool.
 */
export function contextFor(country: string, now = new Date()): string {
  const when = now.toLocaleString(undefined, {
    weekday: "long",
    hour: "numeric",
    minute: "2-digit",
  })
  return [
    `They're using the Forklore website, not the phone, so there are no live numbers from today in this note. Use health_history for anything about their own data; it has whatever their phone has synced.`,
    `Local time: ${when}.`,
    country ? `They cook and eat in ${countryName(country)}.` : `They haven't said where they cook.`,
  ].join("\n")
}

/** A chat's name: its first question, cut short. */
export function titleOf(lines: Line[]): string {
  const first = lines.find((l) => l.who === "you")?.text.trim() ?? ""
  if (!first) return "New chat"
  return first.length > 48 ? `${first.slice(0, 46).trimEnd()}…` : first
}

/** Strips the markup models reach for anyway, as MealReading.clean does on the phone. */
export function clean(text: string): string {
  return text
    .replace(/\*\*/g, "")
    .replace(/ — /g, ", ")
    .replace(/—/g, ", ")
    .replace(/^#+\s*/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
}

export function newId(): string {
  return typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`
}
