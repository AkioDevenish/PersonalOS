"use client"
import Link from "next/link"
import { useParams } from "next/navigation"
import { Page } from "../../shell"
import { Icon } from "../../nav"
import { tint, useArticles } from "../articles"

/** One article, in the long-form serif the phone reads it in. */
export function Reader() {
  const { id } = useParams<{ id: string }>()
  const articles = useArticles()
  const article = articles?.find((a) => a.id === decodeURIComponent(id))

  return (
    <Page>
      <Link href="/read" className="fl-fine inline-flex items-center gap-1 hover:text-[var(--fl-text)]">
        <Icon name="back" size={14} /> Read
      </Link>
      {articles === undefined ? (
        <p className="fl-note mt-8">Loading…</p>
      ) : !article ? (
        <p className="fl-note mt-8">That article isn&apos;t here any more.</p>
      ) : (
        <article className="fl-in mt-6">
          <p className="fl-kicker" style={{ color: tint(article.colour) }}>
            {article.category} · {article.minutes} min read
          </p>
          <h1 className="fl-title mt-3">{article.title}</h1>
          <p className="fl-lede mt-4 italic">{article.summary}</p>
          {article.author && (
            <p className="fl-note mt-4">
              By {article.author}
              {article.credentials ? `, ${article.credentials}` : ""}
            </p>
          )}
          <div className="mt-8 space-y-5">
            {article.locked ? (
              <p className="fl-note">The rest of this article is for subscribers.</p>
            ) : (
              article.body.map((p, i) => (
                <p key={i} className="fl-serif-body text-[19px] leading-[1.7]">
                  {p}
                </p>
              ))
            )}
          </div>
          <p className="fl-fine mt-12">Articles are each writer&apos;s own view, not medical advice.</p>
        </article>
      )}
    </Page>
  )
}
