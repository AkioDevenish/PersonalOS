import type { Metadata } from "next"
import Link from "next/link"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import PageHero from "@/components/marketing/page-hero"
import CtaBand from "@/components/marketing/cta-band"
import { POSTS } from "@/components/landing/content"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

export const metadata: Metadata = {
  title: "News | Personal OS",
  description:
    "What we're building — release notes, roadmap updates, and what's coming next for Personal OS.",
}

export default function NewsPage() {
  const [featured, ...rest] = POSTS

  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <PageHero
            kicker="News"
            title={
              <>
                What we&rsquo;re <em>building.</em>
              </>
            }
            lede="Release notes and roadmap, written plainly. No launch theatre."
          />

          <section className={s.pageSection}>
            <Link href={`/news/${featured.slug}`} className={`${s.featured} ${sh.reveal}`}>
              <p className={s.featuredTag}>Latest · {featured.date}</p>
              <h2 className={s.featuredTitle}>{featured.title}</h2>
              <p className={s.ledgerBody}>{featured.excerpt}</p>
              <span className={s.readMore}>Read the post →</span>
            </Link>

            <div className={s.news}>
              {rest.map((post) => (
                <article key={post.slug} className={`${s.newsRow} ${sh.reveal}`}>
                  <time className={s.newsDate} dateTime={post.dateISO ?? undefined}>
                    {post.date}
                  </time>
                  <div>
                    <Link href={`/news/${post.slug}`}>
                      <h3 className={s.ledgerTitle}>{post.title}</h3>
                    </Link>
                    <p className={s.ledgerBody}>{post.excerpt}</p>
                    <Link href={`/news/${post.slug}`} className={s.readMore}>
                      Read the post →
                    </Link>
                  </div>
                </article>
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
              Built in the open. <br /> Come use it early.
            </>
          }
        />
      </main>

      <SiteFooter />
    </div>
  )
}
