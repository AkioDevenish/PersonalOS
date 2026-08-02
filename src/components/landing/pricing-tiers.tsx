"use client"

import { useState } from "react"
import Link from "next/link"
import { ArrowRight } from "lucide-react"
import { useAuth } from "@clerk/nextjs"
import { TIERS, ANNUAL_MONTHS_CHARGED } from "./content"
import s from "../marketing/marketing.module.css"
import sh from "../shared.module.css"

type Cycle = "monthly" | "annual"

/**
 * Tier plates plus the billing-cycle control. Annual quotes the effective
 * monthly rate — the amount actually charged is spelled out underneath so the
 * headline number is never the misleading one.
 */
export default function PricingTiers() {
  const { isSignedIn } = useAuth()
  const [cycle, setCycle] = useState<Cycle>("monthly")
  const ctaHref = isSignedIn ? "/hub" : "/sign-up"
  const annual = cycle === "annual"

  return (
    <>
      <div className={`${sh.reveal} ${sh.in}`}>
        <div className={s.billing} role="group" aria-label="Billing cycle">
          {(["monthly", "annual"] as Cycle[]).map((c) => (
            <button
              key={c}
              type="button"
              className={s.billingOpt}
              aria-pressed={cycle === c}
              onClick={() => setCycle(c)}
            >
              {c === "monthly" ? "Monthly" : "Annual"}
            </button>
          ))}
        </div>
        <span className={s.billingNote} aria-live="polite">
          {annual ? "Two months free — billed yearly" : " "}
        </span>
      </div>

      <div className={s.tiers}>
        {TIERS.map((t) => {
          const perMonth = annual
            ? (t.monthly * ANNUAL_MONTHS_CHARGED) / 12
            : t.monthly
          // 10/12 of a whole dollar rarely is one — show cents only when needed
          const display = Number.isInteger(perMonth)
            ? `$${perMonth}`
            : `$${perMonth.toFixed(2)}`
          const yearly = t.monthly * ANNUAL_MONTHS_CHARGED

          return (
            <article
              key={t.name}
              className={`${s.tier} ${t.featured ? s.tierFeatured : ""} ${sh.reveal}`}
            >
              {t.featured && <span className={s.tierBadge}>Full access</span>}
              <h3 className={s.tierName}>{t.name}</h3>
              <p className={s.tierSub}>{t.subtitle}</p>

              <p className={s.tierPrice}>
                {display}
                {t.monthly > 0 && <span>/month</span>}
              </p>
              <p className={s.tierBilled}>
                {t.monthly === 0
                  ? "Free forever"
                  : annual
                    ? `$${yearly} billed yearly`
                    : "Billed monthly"}
              </p>

              <div className={s.tierRule} />
              <ul className={s.tierList}>
                {t.features.map((f) => (
                  <li key={f}>{f}</li>
                ))}
              </ul>

              <Link href={ctaHref} className={s.tierCta}>
                {isSignedIn ? "Go to Dashboard" : t.cta} <ArrowRight size={15} />
              </Link>
            </article>
          )
        })}
      </div>
    </>
  )
}
