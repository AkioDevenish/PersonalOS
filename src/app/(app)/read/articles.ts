"use client"
import { useState } from "react"
import { useQuery } from "convex/react"
import { api } from "../../../../convex/_generated/api"
import builtIn from "../../../../ios/Forklore/Articles.json"

export type Article = {
  id: string
  title: string
  category: string
  minutes: number
  colour: string
  summary: string
  body: string[]
  author?: string | null
  credentials?: string | null
  locked?: boolean
}

/** The six the app ships with, from the same file the iOS app bundles. */
export const BUILT_IN: Article[] = builtIn as Article[]

/** Practitioners' published articles first, then the built-in ones. undefined while loading. */
export function useArticles(): Article[] | undefined {
  // Fixed for the visit: the query only uses it to decide whether a subscription has lapsed.
  const [now] = useState(() => Date.now())
  const published = useQuery(api.articles.published, { now })
  if (published === undefined) return undefined
  const written: Article[] = published.map((a) => ({
    id: a.id,
    title: a.title,
    category: a.category,
    minutes: a.minutes,
    colour: a.colour,
    summary: a.summary,
    body: a.body,
    author: a.author,
    credentials: a.credentials,
    locked: a.locked,
  }))
  return [...written, ...BUILT_IN]
}

/** An article's colour, as the hex the phone stores without its #. */
export function tint(colour: string): string {
  return /^[0-9a-f]{6}$/i.test(colour) ? `#${colour}` : "#8C6A4A"
}
