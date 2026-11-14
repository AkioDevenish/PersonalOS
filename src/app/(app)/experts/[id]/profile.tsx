"use client"
import Link from "next/link"
import { useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { useMutation, useQuery } from "convex/react"
import { api } from "../../../../../convex/_generated/api"
import { stamp, update } from "@/web/store"
import { countryName } from "@/web/country"
import { messageOf } from "@/web/errors"
import { Page } from "../../shell"
import { Icon } from "../../nav"
import { Avatar } from "../experts"
import { CONSULTS_KEY, NO_CONSULTS, money, type Started } from "../consults"

/** One practitioner's page, and asking them a question. */
export function Profile() {
  const { id } = useParams<{ id: string }>()
  const router = useRouter()
  const people = useQuery(api.health.consult.directory)
  const open = useMutation(api.health.consult.openSession)
  const [topic, setTopic] = useState("")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")

  const person = people?.find((p) => p.id === decodeURIComponent(id))

  async function start() {
    if (!person) return
    setBusy(true)
    setError("")
    try {
      const session = await open({ specialistId: person.id, kind: "text", topic: topic.trim() || undefined })
      const entry: Started = {
        id: session.id,
        specialistId: person.id,
        name: person.name,
        topic: topic.trim() || "Consultation",
        at: stamp(),
      }
      update<Started[]>(CONSULTS_KEY, NO_CONSULTS, (all) => [entry, ...all].slice(0, 100))
      router.push(`/experts/session/${session.id}`)
    } catch (err) {
      setError(messageOf(err))
      setBusy(false)
    }
  }

  return (
    <Page>
      <Link href="/experts" className="fl-fine inline-flex items-center gap-1 hover:text-[var(--fl-text)]">
        <Icon name="back" size={14} /> Experts
      </Link>
      {people === undefined ? (
        <p className="fl-note mt-8">Loading…</p>
      ) : !person ? (
        <p className="fl-note mt-8">This practitioner isn&apos;t taking questions right now.</p>
      ) : (
        <div className="fl-in mt-6">
          <div className="flex items-center gap-5">
            <Avatar name={person.name} url={person.photo_url} size={88} />
            <div>
              <h1 className="fl-title">{person.name}</h1>
              <p className="fl-note mt-1">{person.credentials}</p>
            </div>
          </div>

          <div className="mt-5 flex flex-wrap gap-2">
            {person.specialties.map((s) => (
              <span key={s} className="fl-chip">
                {s}
              </span>
            ))}
          </div>

          {person.bio && <p className="fl-serif-body mt-6 whitespace-pre-wrap text-[18px] leading-relaxed">{person.bio}</p>}

          <div className="mt-6 flex gap-8">
            <div>
              <p className="fl-kicker">Price</p>
              <p className="fl-serif mt-1 text-[20px]">
                {person.price_minor > 0 ? money(person.price_minor, person.currency) : "Free"}
              </p>
            </div>
            {person.country && (
              <div>
                <p className="fl-kicker">Based in</p>
                <p className="fl-serif mt-1 text-[20px]">{countryName(person.country)}</p>
              </div>
            )}
          </div>

          <section className="fl-plate mt-8">
            <p className="fl-kicker">Ask in writing</p>
            <textarea
              className="fl-textarea mt-3"
              rows={3}
              placeholder="What would you like help with?"
              value={topic}
              maxLength={200}
              onChange={(e) => setTopic(e.target.value)}
            />
            {error && <p className="fl-error mt-2">{error}</p>}
            <button className="fl-btn wide mt-3" onClick={start} disabled={busy}>
              {busy
                ? "Starting…"
                : person.price_minor > 0
                  ? `Start consultation · ${money(person.price_minor, person.currency)}`
                  : "Start consultation"}
            </button>
            <p className="fl-fine mt-3">
              {person.price_minor > 0
                ? "You'll pay on a secure checkout page before the conversation opens."
                : "You'll get a notification on your phone when they reply."}
              {person.offers_video ? " Video calls are in the iOS app." : ""}
            </p>
          </section>
        </div>
      )}
    </Page>
  )
}
