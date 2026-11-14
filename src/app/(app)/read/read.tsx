"use client"
import Link from "next/link"
import { Header, Page } from "../shell"
import { tint, useArticles, type Article } from "./articles"

/** Articles: what practitioners have written and the team verified, plus the built-in ones. */
export function Read() {
  const articles = useArticles()

  return (
    <Page wide>
      <Header kicker="Read" title="Short reads on food and your body." />
      {articles === undefined ? (
        <p className="fl-note mt-8">Loading…</p>
      ) : (
        <>
          <p className="fl-kicker mt-10">Featured</p>
          <div className="mt-3 grid gap-4 sm:grid-cols-2">
            {articles.slice(0, 2).map((a) => (
              <Card key={a.id} article={a} big />
            ))}
          </div>
          {articles.length > 2 && (
            <>
              <p className="fl-kicker mt-10">More</p>
              <div className="mt-3 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {articles.slice(2).map((a) => (
                  <Card key={a.id} article={a} />
                ))}
              </div>
            </>
          )}
        </>
      )}
    </Page>
  )
}

function Card({ article, big = false }: { article: Article; big?: boolean }) {
  const colour = tint(article.colour)
  return (
    <Link
      href={`/read/${encodeURIComponent(article.id)}`}
      className="fl-plate fl-in flex flex-col transition-transform hover:-translate-y-0.5"
      style={{ borderTop: `3px solid ${colour}` }}
    >
      <p className="fl-kicker" style={{ color: colour }}>
        {article.category} · {article.minutes} min
      </p>
      <h2 className={`fl-serif mt-2 leading-snug ${big ? "text-[26px]" : "text-[21px]"}`}>{article.title}</h2>
      <p className="fl-note mt-2 line-clamp-3">{article.summary}</p>
      {article.author && <p className="fl-fine mt-auto pt-3">By {article.author}</p>}
    </Link>
  )
}
