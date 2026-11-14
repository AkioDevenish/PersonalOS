"use client"
import { useCallback, useSyncExternalStore } from "react"

/**
 * Small values kept in this browser only, the web's stand-in for what the phone keeps on the
 * device (chats, the chosen country, recent meal ideas). Every read and write survives a browser
 * that refuses storage.
 */

const listeners = new Map<string, Set<() => void>>()
const cache = new Map<string, { raw: string | null; value: unknown }>()

function read<T>(key: string, fallback: T): T {
  let raw: string | null = null
  try {
    raw = window.localStorage.getItem(key)
  } catch {
    raw = null
  }
  const hit = cache.get(key)
  if (hit && hit.raw === raw) return hit.value as T
  let value: T = fallback
  if (raw !== null) {
    try {
      value = JSON.parse(raw) as T
    } catch {
      value = fallback
    }
  }
  cache.set(key, { raw, value })
  return value
}

/** Changes a stored value from its latest state, not from what a page rendered earlier. */
export function update<T>(key: string, fallback: T, change: (current: T) => T) {
  write(key, change(read(key, fallback)))
}

export function write<T>(key: string, value: T) {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Private windows and full disks: the value just doesn't outlive the tab.
    cache.set(key, { raw: JSON.stringify(value), value })
  }
  listeners.get(key)?.forEach((l) => l())
}

export function useStored<T>(key: string, fallback: T): [T, (next: T) => void] {
  const subscribe = useCallback(
    (listener: () => void) => {
      const set = listeners.get(key) ?? new Set()
      set.add(listener)
      listeners.set(key, set)
      const onStorage = (e: StorageEvent) => e.key === key && listener()
      window.addEventListener("storage", onStorage)
      return () => {
        set.delete(listener)
        window.removeEventListener("storage", onStorage)
      }
    },
    [key],
  )
  const value = useSyncExternalStore(
    subscribe,
    () => read(key, fallback),
    () => fallback,
  )
  const set = useCallback((next: T) => write(key, next), [key])
  return [value, set]
}

/** The time now, for stamping a row as it is saved (never read during render). */
export function stamp(): number {
  return Date.now()
}
