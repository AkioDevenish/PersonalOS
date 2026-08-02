"use client"

import { useEffect, useRef } from "react"
import s from "../shared.module.css"

/**
 * Adds the shared `in` class to any `.reveal` descendant as it scrolls into
 * view. StoryClient runs its own observer as part of the scrubbed timeline;
 * this is the standalone-page equivalent.
 */
export default function Reveal({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const root = ref.current
    if (!root) return

    const els = Array.from(root.querySelectorAll<HTMLElement>(`.${s.reveal}`))

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      els.forEach((el) => el.classList.add(s.in))
      return
    }

    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (e.isIntersecting) (e.target as HTMLElement).classList.add(s.in)
        }),
      { threshold: 0.2 }
    )
    els.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])

  return <div ref={ref}>{children}</div>
}
