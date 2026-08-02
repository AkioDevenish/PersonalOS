import type { Metadata } from "next"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import PageHero from "@/components/marketing/page-hero"
import Faq from "@/components/marketing/faq"
import CtaBand from "@/components/marketing/cta-band"
import { PILLARS, STEPS, INTEGRATIONS, HOW_FAQ } from "@/components/landing/content"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "How it works | Personal OS",
  description:
    "Five pillars, one operating system. Connect your data once, let AI read across all of it, and get a single briefing instead of ten dashboards.",
}

export default function HowItWorksPage() {
  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <PageHero
            kicker="How it works"
            title={
              <>
                Five pillars. <em>One operating system.</em>
              </>
            }
            lede="Today's tools scatter your life across silos. Personal OS ingests that data for you, runs AI across it, and returns guidance — without the daily bottleneck of context-switching."
          />

          <section className={s.pageSection}>
            <div className={s.steps}>
              {STEPS.map((st) => (
                <div key={st.numeral} className={`${s.step} ${sh.reveal}`}>
                  <span className={s.stepNumeral}>{st.numeral}</span>
                  <h3 className={s.ledgerTitle}>{st.title}</h3>
                  <p className={s.ledgerBody}>{st.body}</p>
                </div>
              ))}
            </div>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>What flows in</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              Connected once, <em>then quiet.</em>
            </h2>
            <p className={`${s.prose} ${sh.reveal}`}>
              Every source below is read-only and configured a single time. After that
              the data arrives on its own — there is no app to open and no daily ritual
              to keep up.
            </p>

            <div className={s.dataList}>
              {INTEGRATIONS.map((it) => (
                <div key={it.title} className={`${s.dataItem} ${sh.reveal}`}>
                  <h3>{it.title}</h3>
                  <p>{it.body}</p>
                </div>
              ))}
            </div>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>The pillars</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              Five that ship. <em>One that&rsquo;s yours.</em>
            </h2>

            <div className={s.ledger}>
              {PILLARS.map((p) => (
                <article key={p.title} className={`${s.ledgerRow} ${sh.reveal}`}>
                  <span className={s.ledgerNumeral}>{p.numeral}</span>
                  <div>
                    <h3 className={s.ledgerTitle}>{p.title}</h3>
                    <p className={s.ledgerBody}>{p.body}</p>
                  </div>
                </article>
              ))}
            </div>

            <p className={`${s.footnotes} ${sh.reveal}`}>
              Gemma &amp; Ollama ready <b>❧</b> BYOK supported <b>❧</b> Health MVP live
            </p>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>Questions</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              The things worth <em>asking first.</em>
            </h2>
            <Faq entries={HOW_FAQ} />
          </section>
        </Reveal>

        <CtaBand
          title={
            <>
              Connect once. <br /> Read one briefing.
            </>
          }
        />
      </main>

      <SiteFooter />
    </div>
  )
}
