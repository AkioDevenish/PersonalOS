import type { Metadata } from "next"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import PricingTiers from "@/components/landing/pricing-tiers"
import PageHero from "@/components/marketing/page-hero"
import Faq from "@/components/marketing/faq"
import CtaBand from "@/components/marketing/cta-band"
import { COMPARE_ROWS, PRICING_FAQ } from "@/components/landing/content"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "Pricing | Personal OS",
  description:
    "Free to run, pay when you need more. Use Gemma and Ollama at no cost, or unlock the full OS with frontier models. Annual billing saves two months.",
}

function Cell({ value }: { value: string | boolean }) {
  if (value === true) return <span className={s.compareYes} aria-label="Included">❧</span>
  if (value === false) return <span className={s.compareNo} aria-label="Not included">—</span>
  return <>{value}</>
}

export default function PricingPage() {
  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <PageHero
            kicker="Pricing"
            title={
              <>
                Free to run. <em>Pay when you need more.</em>
              </>
            }
            lede="Use Gemma and Ollama at no cost, or unlock the full OS with frontier models. Your data stays local on every tier."
          />

          <section className={s.pageSection}>
            <PricingTiers />

            <div className={`${s.compareWrap} ${sh.reveal}`}>
              <table className={s.compare}>
                <caption>Everything, side by side</caption>
                <thead>
                  <tr>
                    <th scope="col">Feature</th>
                    <th scope="col">Free</th>
                    <th scope="col">Pro</th>
                    <th scope="col">Enterprise</th>
                  </tr>
                </thead>
                <tbody>
                  {COMPARE_ROWS.map((row) => (
                    <tr key={row.feature}>
                      <th scope="row">{row.feature}</th>
                      <td><Cell value={row.free} /></td>
                      <td><Cell value={row.pro} /></td>
                      <td><Cell value={row.enterprise} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>Questions</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              Before you <em>decide.</em>
            </h2>
            <Faq entries={PRICING_FAQ} />
          </section>
        </Reveal>

        <CtaBand
          title={
            <>
              Start free. <br /> Pay only if it earns it.
            </>
          }
          label="Start free"
        />
      </main>

      <SiteFooter />
    </div>
  )
}
