"use client"
import Link from "next/link"
import { useState } from "react"
import { useQuery } from "convex/react"
import { api } from "../../../../convex/_generated/api"
import { useStored } from "@/web/store"
import { countryName } from "@/web/country"
import { Header, Page } from "../shell"
import { CONSULTS_KEY, NO_CONSULTS, money, presence, type Started } from "./consults"

/** The directory of practitioners, and the consultations already going. */
export function Experts() {
  const people = useQuery(api.health.consult.directory)
  const abilities = useQuery(api.articles.abilities)
  const [started] = useStored<Started[]>(CONSULTS_KEY, NO_CONSULTS)
  const [now] = useState(() => Date.now())

  return (
    <Page wide>
      <Header
        kicker="Experts"
        title="Talk to a real nutritionist."
        lede="Ask in writing and get an answer from a person who does this for a living."
      />

      {abilities?.canWrite && <Queue />}

      {started.length > 0 && (
        <section className="mt-10">
          <p className="fl-kicker">Your consultations</p>
          <ul className="mt-2">
            {started.map((c) => (
              <li key={c.id}>
                <Link href={`/experts/session/${c.id}`} className="fl-row hover:opacity-80">
                  <span className="min-w-0 flex-1">
                    <span className="fl-serif block truncate text-[18px]">{c.topic}</span>
                    <span className="fl-fine">
                      with {c.name} · {new Date(c.at).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                    </span>
                  </span>
                  <span className="fl-serif text-[var(--fl-text-3)]">›</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-10">
        <p className="fl-kicker">Practitioners</p>
        {people === undefined ? (
          <p className="fl-note mt-4">Loading…</p>
        ) : people.length === 0 ? (
          <p className="fl-note mt-4">Nobody is taking questions right now. Check back soon.</p>
        ) : (
          <div className="mt-3 grid gap-4 sm:grid-cols-2">
            {people.map((p) => {
              const here = presence(p.last_seen, now)
              return (
                <Link key={p.id} href={`/experts/${p.id}`} className="fl-plate fl-in flex gap-4 hover:-translate-y-0.5">
                  <Avatar name={p.name} url={p.photo_url} />
                  <div className="min-w-0 flex-1">
                    <p className="fl-serif text-[20px] leading-tight">{p.name}</p>
                    <p className="fl-note mt-0.5 line-clamp-1">{p.credentials}</p>
                    <p className="fl-fine mt-2">
                      {p.price_minor > 0 ? money(p.price_minor, p.currency) : "Free"}
                      {p.country ? ` · ${countryName(p.country)}` : ""}
                      {here ? ` · ${here}` : ""}
                    </p>
                  </div>
                </Link>
              )
            })}
          </div>
        )}
      </section>

      <p className="fl-fine mt-10">
        Practitioners apply from the iOS app, under Profile. Video calls are in the iOS app too.
      </p>
    </Page>
  )
}

/** For an approved practitioner: the people waiting on them. */
function Queue() {
  const queue = useQuery(api.health.consult.queue)
  if (!queue || queue.length === 0) return null
  return (
    <section className="mt-10">
      <p className="fl-kicker accent">Waiting on you</p>
      <ul className="mt-2">
        {queue.map((q) => (
          <li key={q.id}>
            <Link href={`/experts/session/${q.id}`} className="fl-row hover:opacity-80">
              <span className="min-w-0 flex-1">
                <span className="fl-serif block truncate text-[18px]">{q.topic}</span>
                <span className="fl-fine line-clamp-1">{q.last_message || "No messages yet"}</span>
              </span>
              {q.needs_reply && <span className="fl-kicker accent">Reply</span>}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  )
}

export function Avatar({ name, url, size = 56 }: { name: string; url: string | null; size?: number }) {
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("")
  return url ? (
    // eslint-disable-next-line @next/next/no-img-element -- a signed storage URL, not a static asset
    <img src={url} alt="" width={size} height={size} className="shrink-0 rounded-full object-cover" style={{ width: size, height: size }} />
  ) : (
    <span
      className="fl-serif flex shrink-0 items-center justify-center rounded-full bg-[var(--fl-raised)] text-[var(--fl-accent)]"
      style={{ width: size, height: size, fontSize: size * 0.38 }}
    >
      {initials}
    </span>
  )
}
