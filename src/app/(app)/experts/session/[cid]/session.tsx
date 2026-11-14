"use client"
import Link from "next/link"
import { useEffect, useRef, useState } from "react"
import { useParams } from "next/navigation"
import { useAction, useMutation, useQuery } from "convex/react"
import { api } from "../../../../../../convex/_generated/api"
import type { Id } from "../../../../../../convex/_generated/dataModel"
import { useStored } from "@/web/store"
import { messageOf } from "@/web/errors"
import { Page } from "../../../shell"
import { Icon } from "../../../nav"
import { CONSULTS_KEY, NO_CONSULTS, money, type Started } from "../../consults"

/** A written consultation, from either side. */
export function Session() {
  const { cid } = useParams<{ cid: string }>()
  const id = cid as Id<"consults">
  const [started] = useStored<Started[]>(CONSULTS_KEY, NO_CONSULTS)
  // Who booked it is the one who pays; the practitioner answering it never sees the bill.
  const mine = started.find((c) => c.id === cid)
  const thread = useQuery(api.health.consult.thread, { id })
  const bill = useQuery(api.health.consult.billing, mine ? { id } : "skip")
  const send = useMutation(api.health.consult.send)
  const [draft, setDraft] = useState("")
  const [error, setError] = useState("")
  const bottom = useRef<HTMLDivElement>(null)

  const unpaid = bill?.payment_status === "pending"
  const count = thread?.messages.length ?? 0

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" })
  }, [count])

  async function submit() {
    const body = draft.trim()
    if (!body) return
    setError("")
    setDraft("")
    try {
      await send({ id, body })
    } catch (err) {
      setDraft(body)
      setError(messageOf(err))
    }
  }

  return (
    <Page>
      <Link href="/experts" className="fl-fine inline-flex items-center gap-1 hover:text-[var(--fl-text)]">
        <Icon name="back" size={14} /> Experts
      </Link>
      {thread === undefined ? (
        <p className="fl-note mt-8">Loading…</p>
      ) : (
        <div className="fl-in mt-6 flex min-h-[60dvh] flex-col">
          <p className="fl-kicker">{mine ? `With ${mine.name}` : "Consultation"}</p>
          <h1 className="fl-title mt-2">{thread.topic}</h1>
          <p className="fl-fine mt-2">
            {thread.status === "answered" ? "Answered" : "Waiting for a reply"} · started{" "}
            {new Date(thread.created_at).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
          </p>

          {unpaid && bill && <Payment id={id} price={money(bill.price_minor, bill.currency)} />}

          <div className="mt-8 flex flex-1 flex-col gap-4">
            {thread.messages.length === 0 && !unpaid && (
              <p className="fl-note">Say what you&apos;d like help with. They&apos;ll get a notification.</p>
            )}
            {thread.messages.map((m) => {
              const fromMe = mine ? m.from === "you" : m.from !== "you"
              return (
                <div key={m.id} className={`flex flex-col ${fromMe ? "items-end" : "items-start"}`}>
                  <p className={fromMe ? "fl-bubble-you" : "fl-bubble-them"}>{m.body}</p>
                  <span className="fl-fine mt-1">
                    {new Date(m.created_at).toLocaleString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "numeric",
                      minute: "2-digit",
                    })}
                  </span>
                </div>
              )
            })}
            <div ref={bottom} />
          </div>

          {!unpaid && (
            <form
              className="sticky bottom-0 mt-6 bg-gradient-to-t from-[var(--fl-bg-2)] via-[var(--fl-bg-2)] to-transparent pb-5 pt-4"
              onSubmit={(e) => {
                e.preventDefault()
                submit()
              }}
            >
              {error && <p className="fl-error mb-2">{error}</p>}
              <div className="flex items-end gap-2 rounded-[26px] border border-[var(--fl-line)] bg-[var(--fl-raised)] focus-within:border-[color-mix(in_srgb,var(--fl-accent)_55%,transparent)] p-2 pl-4 shadow-[var(--fl-shadow)]">
                <textarea
                  className="max-h-40 flex-1 fl-bare resize-none bg-transparent py-2 text-[15px] outline-none placeholder:text-[var(--fl-text-3)]"
                  rows={2}
                  placeholder="Write a message…"
                  value={draft}
                  maxLength={4000}
                  onChange={(e) => setDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
                      e.preventDefault()
                      submit()
                    }
                  }}
                />
                <button
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--fl-text)] text-[var(--fl-bg)] disabled:opacity-30"
                  aria-label="Send"
                  disabled={!draft.trim()}
                >
                  <Icon name="send" />
                </button>
              </div>
            </form>
          )}
        </div>
      )}
    </Page>
  )
}

/** Paying for a priced consultation: a checkout page, then asking the processor whether it went through. */
function Payment({ id, price }: { id: Id<"consults">; price: string }) {
  const checkout = useAction(api.consultPayments.checkout)
  const settled = useAction(api.consultPayments.settled)
  const [busy, setBusy] = useState(false)
  const [note, setNote] = useState("")
  // Shown as a link rather than opened from script, which browsers block after a wait.
  const [url, setUrl] = useState("")

  async function pay() {
    setBusy(true)
    setNote("")
    try {
      const result = await checkout({ id })
      if (result.paid) return
      if (result.url) {
        setUrl(result.url)
      } else {
        setNote(result.error ?? "Payments aren't working right now. Try again later.")
      }
    } catch (err) {
      setNote(messageOf(err))
    } finally {
      setBusy(false)
    }
  }

  async function check() {
    setBusy(true)
    setNote("")
    try {
      const { paid } = await settled({ id })
      if (!paid) setNote("The payment hasn't come through yet. If you've just paid, give it a minute.")
    } catch (err) {
      setNote(messageOf(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="fl-plate mt-6">
      <p className="fl-kicker accent">Payment needed</p>
      <p className="fl-serif-body mt-2 text-[17px]">
        This consultation is {price}. The conversation opens once it&apos;s paid.
      </p>
      <div className="mt-4 flex flex-wrap gap-2">
        {url ? (
          <a className="fl-btn" href={url} target="_blank" rel="noopener noreferrer">
            Open checkout
          </a>
        ) : (
          <button className="fl-btn" onClick={pay} disabled={busy}>
            Pay {price}
          </button>
        )}
        {url && (
          <button className="fl-btn ghost" onClick={check} disabled={busy}>
            I&apos;ve paid
          </button>
        )}
      </div>
      {note && <p className="fl-note mt-3">{note}</p>}
    </section>
  )
}
