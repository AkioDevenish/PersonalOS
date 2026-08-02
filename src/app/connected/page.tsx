import type { Metadata } from "next"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "Connected | Personal OS",
  robots: { index: false },
}

type Search = Promise<{ connected?: string; error?: string; cancelled?: string }>

/**
 * Where an OAuth link lands.
 *
 * Providers redirect to a web URL, not an app — so even with no web dashboard
 * there has to be a page here to receive the callback and tell the user to go
 * back to their phone. This is the whole of the "web app" a mobile-only
 * product still needs.
 */
export default async function ConnectedPage({ searchParams }: { searchParams: Search }) {
  const { connected, error, cancelled } = await searchParams

  const heading = error
    ? "That didn't work"
    : cancelled
      ? "Connection cancelled"
      : "You're connected"

  const detail = error
    ? error
    : cancelled
      ? "Nothing was linked. You can try again from the app whenever you like."
      : `${connected ?? "Your account"} is linked. Data will start arriving shortly — you can close this window and return to the app.`

  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <section className={s.pageSection}>
          <p className={s.sectionKicker}>{error || cancelled ? "Not linked" : "All set"}</p>
          <h1 className={s.sectionTitle}>{heading}</h1>
          <p className={s.prose}>{detail}</p>

          <div className={sh.ruleOrnament}>
            <i /><b>❧</b><i />
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  )
}
