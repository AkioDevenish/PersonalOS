import type { Metadata } from "next"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import PageHero from "@/components/marketing/page-hero"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "Get the app | Personal OS",
  description:
    "Personal OS runs on your phone, where your health data already lives. Coming to iOS and Android.",
}

/**
 * Where every call to action now leads.
 *
 * Personal OS is a phone app — there is no web dashboard to send people to.
 * Apple Health and Health Connect are readable only by an app on the device
 * itself, so the phone isn't a companion to the product, it is the product.
 */
export default function DownloadPage() {
  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <PageHero
            kicker="Get the app"
            title={
              <>
                It lives on your <em>phone.</em>
              </>
            }
            lede="Your health data never leaves your device unless an app on it sends it — so that's where Personal OS runs."
          />

          <section className={s.pageSection}>
            <div className={s.principles}>
              {[
                {
                  numeral: "I",
                  title: "iOS — in development",
                  body: "Reads Apple Health and Apple Watch in the background. Nothing to open, nothing to sync by hand.",
                },
                {
                  numeral: "II",
                  title: "Android — in development",
                  body: "Health Connect and Samsung Health, the same way.",
                },
              ].map((p) => (
                <article key={p.title} className={`${s.principle} ${sh.reveal}`}>
                  <span className={s.principleNum}>{p.numeral}</span>
                  <div>
                    <h3 className={s.ledgerTitle}>{p.title}</h3>
                    <p className={s.ledgerBody}>{p.body}</p>
                  </div>
                </article>
              ))}
            </div>

            <p className={`${s.footnotes} ${sh.reveal}`}>
              Not on the stores yet <b>❧</b> No sign-up required to wait
            </p>

            <div className={`${sh.ruleOrnament} ${sh.reveal}`}>
              <i /><b>❧</b><i />
            </div>
          </section>
        </Reveal>
      </main>

      <SiteFooter />
    </div>
  )
}
