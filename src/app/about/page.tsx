import type { Metadata } from "next"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import PageHero from "@/components/marketing/page-hero"
import CtaBand from "@/components/marketing/cta-band"
import { PRINCIPLES, MILESTONES } from "@/components/landing/content"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "About Us | Personal OS",
  description:
    "One place for the life you're already living. Personal OS pulls your data in, layers AI on top, and gives you a single surface that improves with you.",
}

export default function AboutPage() {
  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <PageHero
            kicker="About us"
            title={
              <>
                One place for the life you&rsquo;re <em>already living.</em>
              </>
            }
            lede="Personal OS is a single surface for the four currencies you actually spend — time, vitality, connection, and craft."
          />

          <section className={s.pageSection}>
            <div className={s.twoCol}>
              <div className={sh.reveal}>
                <p>
                  Phones and computers expect you to meet them. Open ten apps, check
                  email, log a workout, review finances, remember the birthday. Every
                  tool you own asks for a few minutes a day, and together they ask for
                  the day.
                </p>
                <p>
                  The cost isn&rsquo;t the minutes. It&rsquo;s the context-switching —
                  the tax you pay reassembling a picture of your own life out of a
                  dozen dashboards that don&rsquo;t speak to each other.
                </p>
              </div>
              <div className={sh.reveal}>
                <p>
                  Personal OS inverts the relationship. Your data flows in through
                  integrations you set up once. AI reads across all of it, not one silo
                  at a time. What comes back is guidance, not another chart to
                  interpret.
                </p>
                <p>
                  Minimal setup. Bring your own keys, or start free with a local model
                  on your own machine. Your ledger stays yours.
                </p>
              </div>
            </div>

            <blockquote className={`${s.pullQuote} ${sh.reveal}`}>
              A system should hand you the day, not ask you to assemble it.
              <cite>The premise</cite>
            </blockquote>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>What we hold to</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              Four principles, <em>kept honestly.</em>
            </h2>

            <div className={s.principles}>
              {PRINCIPLES.map((p) => (
                <article key={p.title} className={`${s.principle} ${sh.reveal}`}>
                  <span className={s.principleNum}>{p.numeral}</span>
                  <div>
                    <h3 className={s.ledgerTitle}>{p.title}</h3>
                    <p className={s.ledgerBody}>{p.body}</p>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section className={s.pageSection}>
            <p className={`${s.sectionKicker} ${sh.reveal}`}>The ledger so far</p>
            <h2 className={`${s.sectionTitle} ${sh.reveal}`}>
              Built in the open, <em>one pillar at a time.</em>
            </h2>

            <div className={s.timeline}>
              {MILESTONES.map((m) => (
                <div
                  key={m.title}
                  className={`${s.timelineRow} ${sh.reveal}`}
                  data-done={m.done}
                >
                  <p className={s.timelineWhen}>{m.when}</p>
                  <h3 className={s.ledgerTitle}>{m.title}</h3>
                  <p className={s.ledgerBody}>{m.body}</p>
                </div>
              ))}
            </div>

            <div className={`${sh.ruleOrnament} ${sh.reveal}`}>
              <i /><b>❧</b><i />
            </div>
          </section>
        </Reveal>

        <CtaBand
          title={
            <>
              Start with the hours <br /> you already have.
            </>
          }
        />
      </main>

      <SiteFooter />
    </div>
  )
}
