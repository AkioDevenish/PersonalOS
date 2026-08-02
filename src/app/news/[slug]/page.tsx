import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"
import SiteHeader from "@/components/layout/site-header"
import SiteFooter from "@/components/layout/site-footer"
import Reveal from "@/components/landing/reveal"
import CtaBand from "@/components/marketing/cta-band"
import { POSTS } from "@/components/landing/content"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"

type Params = Promise<{ slug: string }>

export function generateStaticParams() {
  return POSTS.map((p) => ({ slug: p.slug }))
}

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params
  const post = POSTS.find((p) => p.slug === slug)
  if (!post) return { title: "Not found | Personal OS" }

  return {
    title: `${post.title} | Personal OS`,
    description: post.excerpt,
    openGraph: {
      type: "article",
      title: post.title,
      description: post.excerpt,
      publishedTime: post.dateISO ?? undefined,
    },
  }
}

export default async function PostPage({ params }: { params: Params }) {
  const { slug } = await params
  const index = POSTS.findIndex((p) => p.slug === slug)
  if (index === -1) notFound()

  const post = POSTS[index]
  // POSTS is newest-first: the next post chronologically sits at a lower index
  const newer = POSTS[index - 1]
  const older = POSTS[index + 1]

  return (
    <div className={sh.page}>
      <SiteHeader />

      <main className={sh.standalone}>
        <Reveal>
          <article className={s.pageSection}>
            <div className={s.article}>
              <Link href="/news" className={s.backLink}>
                ← All news
              </Link>

              <h1 className={s.articleTitle}>{post.title}</h1>
              <p className={s.articleMeta}>
                <time dateTime={post.dateISO ?? undefined}>{post.date}</time>
              </p>

              <div className={s.articleBody}>
                {post.body.map((block, i) => {
                  if (block.type === "h2") return <h2 key={i}>{block.text}</h2>
                  if (block.type === "ul")
                    return (
                      <ul key={i}>
                        {block.items.map((item) => (
                          <li key={item}>{item}</li>
                        ))}
                      </ul>
                    )
                  return <p key={i}>{block.text}</p>
                })}
              </div>
            </div>

            <nav className={s.postNav} aria-label="More posts">
              {older ? (
                <Link href={`/news/${older.slug}`}>
                  <span>Older</span>
                  <b>{older.title}</b>
                </Link>
              ) : (
                <span />
              )}
              {newer && (
                <Link href={`/news/${newer.slug}`} className={s.postNavNext}>
                  <span>Newer</span>
                  <b>{newer.title}</b>
                </Link>
              )}
            </nav>
          </article>
        </Reveal>

        <CtaBand
          title={
            <>
              Read it here. <br /> Then go run it.
            </>
          }
        />
      </main>

      <SiteFooter />
    </div>
  )
}
