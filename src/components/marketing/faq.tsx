"use client"

import { useId, useState } from "react"
import s from "./marketing.module.css"
import sh from "../shared.module.css"

export type FaqEntry = { q: string; a: string }

/**
 * Accessible disclosure list. One panel open at a time; clicking the open
 * question closes it. Height animates via grid-template-rows 0fr → 1fr so
 * nothing has to be measured, and the panel stays in the a11y tree.
 */
export default function Faq({ entries }: { entries: FaqEntry[] }) {
  const [open, setOpen] = useState<number | null>(0)
  const baseId = useId()

  return (
    <div className={`${s.faq} ${sh.reveal}`}>
      {entries.map((entry, i) => {
        const isOpen = open === i
        const btnId = `${baseId}-q-${i}`
        const panelId = `${baseId}-a-${i}`

        return (
          <div key={entry.q} className={s.faqItem}>
            <h3>
              <button
                type="button"
                id={btnId}
                className={s.faqQ}
                aria-expanded={isOpen}
                aria-controls={panelId}
                onClick={() => setOpen(isOpen ? null : i)}
              >
                {entry.q}
                <span className={s.faqSign} aria-hidden="true" />
              </button>
            </h3>
            <div
              id={panelId}
              role="region"
              aria-labelledby={btnId}
              className={s.faqA}
              data-open={isOpen}
              // hidden from AT only once collapsed, so the open panel reads normally
              inert={!isOpen || undefined}
            >
              <div>
                <p>{entry.a}</p>
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}
