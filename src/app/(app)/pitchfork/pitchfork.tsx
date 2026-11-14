"use client"
import { useEffect, useRef, useState } from "react"
import { useAction } from "convex/react"
import { api } from "../../../../convex/_generated/api"
import { stamp, update, useStored } from "@/web/store"
import { useCountry } from "@/web/country"
import { messageOf } from "@/web/errors"
import {
  CHATS_KEY,
  CURRENT_KEY,
  MAX_CHATS,
  NO_CHATS,
  clean,
  contextFor,
  newId,
  titleOf,
  type Chat,
  type Line,
} from "@/web/pitchfork"
import { Icon } from "../nav"

const STARTERS = [
  "What should I have for lunch?",
  "How did I sleep this week?",
  "Something quick with what's in my fridge",
  "Am I moving more than last week?",
]

/**
 * The chat. Replies come from convex/health/pitchfork.ts, which can read the person's synced
 * health history. Chats are kept in this browser only.
 */
export function Pitchfork() {
  const reply = useAction(api.health.pitchfork.reply)
  const [chats, setChats] = useStored<Chat[]>(CHATS_KEY, NO_CHATS)
  const [currentId, setCurrentId] = useStored<string>(CURRENT_KEY, "")
  const [country] = useCountry()
  const [draft, setDraft] = useState("")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")
  const [showHistory, setShowHistory] = useState(false)
  const bottom = useRef<HTMLDivElement>(null)

  const current = chats.find((c) => c.id === currentId)
  const lines = current?.lines ?? []

  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth", block: "end" })
  }, [lines.length, busy])

  function save(id: string, next: Line[]) {
    const chat: Chat = { id, title: titleOf(next), lines: next, updated: stamp() }
    update<Chat[]>(CHATS_KEY, NO_CHATS, (all) => [chat, ...all.filter((c) => c.id !== id)].slice(0, MAX_CHATS))
  }

  async function send(text: string) {
    const question = text.trim()
    if (!question || busy) return
    const id = current?.id ?? newId()
    if (!current) setCurrentId(id)
    const asked: Line[] = [...lines, { who: "you", text: question }]
    save(id, asked)
    setDraft("")
    setError("")
    setBusy(true)
    try {
      const answer = await reply({
        lines: asked.map(({ who, text }) => ({ who, text })),
        context: contextFor(country),
      })
      save(id, [...asked, { who: "assistant", text: clean(answer.text), looked: answer.looked }])
    } catch (err) {
      setError(messageOf(err))
    } finally {
      setBusy(false)
    }
  }

  function startNew() {
    setCurrentId("")
    setShowHistory(false)
    setError("")
  }

  function remove(id: string) {
    setChats(chats.filter((c) => c.id !== id))
    if (id === currentId) setCurrentId("")
  }

  return (
    <div className="mx-auto flex min-h-[calc(100dvh-56px)] w-full max-w-2xl flex-col px-5 lg:min-h-dvh">
      <div className="sticky top-0 z-10 -mx-5 flex items-center justify-center gap-2 px-5 py-3 lg:pt-6">
        <button
          className="flex items-center gap-2 rounded-full border border-[var(--fl-line)] bg-[var(--fl-raised)] px-4 py-2 text-sm shadow-[var(--fl-shadow)] backdrop-blur"
          onClick={() => setShowHistory(!showHistory)}
          aria-expanded={showHistory}
        >
          <Icon name="history" size={15} />
          <span className="max-w-[16rem] truncate">{current?.title ?? "New chat"}</span>
        </button>
        {current && (
          <button
            className="flex h-9 w-9 items-center justify-center rounded-full border border-[var(--fl-line)] bg-[var(--fl-raised)] shadow-[var(--fl-shadow)]"
            aria-label="New chat"
            onClick={startNew}
          >
            <Icon name="plus" size={16} />
          </button>
        )}
      </div>

      {showHistory && (
        <div className="fl-plate fl-in mb-4">
          <div className="flex items-center justify-between">
            <p className="fl-kicker">Past chats</p>
            <button className="fl-btn small ghost" onClick={startNew}>
              New chat
            </button>
          </div>
          {chats.length === 0 ? (
            <p className="fl-note mt-3">No chats yet. They&apos;re kept in this browser only.</p>
          ) : (
            <ul className="mt-2">
              {chats.map((c) => (
                <li key={c.id} className="flex items-center gap-2 border-b border-[var(--fl-line)] last:border-0">
                  <button
                    className="flex-1 truncate py-3 text-left"
                    onClick={() => {
                      setCurrentId(c.id)
                      setShowHistory(false)
                    }}
                  >
                    <span className={c.id === currentId ? "font-medium" : ""}>{c.title}</span>
                    <span className="fl-fine ml-2">
                      {new Date(c.updated).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
                    </span>
                  </button>
                  <button className="fl-fine px-2 hover:text-[var(--fl-danger)]" onClick={() => remove(c.id)}>
                    Delete
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className="flex flex-1 flex-col gap-5 pb-6">
        {lines.length === 0 ? (
          <div className="fl-in flex flex-1 flex-col items-center justify-center py-10 text-center">
            <div className={`fl-blob ${busy ? "busy" : ""}`} />
            <h1 className="fl-serif mt-8 text-[30px]">What can I help with?</h1>
            <p className="fl-note mt-2 max-w-sm">
              Ask about food, cooking, or your own numbers. Pitchfork can look at what your phone has synced.
            </p>
            <div className="mt-6 flex flex-wrap justify-center gap-2">
              {STARTERS.map((s) => (
                <button key={s} className="fl-chip hover:bg-[var(--fl-surface)]" onClick={() => send(s)}>
                  {s}
                </button>
              ))}
            </div>
          </div>
        ) : (
          lines.map((line, i) =>
            line.who === "you" ? (
              <p key={i} className="fl-bubble-you fl-in">
                {line.text}
              </p>
            ) : (
              <div key={i} className="fl-in flex flex-col gap-2">
                {line.looked && line.looked.length > 0 && (
                  <ul className="flex flex-col gap-1">
                    {line.looked.map((l, j) => (
                      <li key={j} className="fl-fine">
                        ✓ {l}
                      </li>
                    ))}
                  </ul>
                )}
                <p className="fl-bubble-them">{line.text}</p>
              </div>
            ),
          )
        )}
        {busy && (
          <div className="fl-dots py-2" aria-label="Pitchfork is thinking">
            <span />
            <span />
            <span />
          </div>
        )}
        {error && <p className="fl-error">{error}</p>}
        <div ref={bottom} />
      </div>

      <form
        className="sticky bottom-0 -mx-5 bg-gradient-to-t from-[var(--fl-bg-2)] via-[var(--fl-bg-2)] to-transparent px-5 pb-5 pt-6"
        onSubmit={(e) => {
          e.preventDefault()
          send(draft)
        }}
      >
        <div className="flex items-end gap-2 rounded-[26px] border border-[var(--fl-line)] bg-[var(--fl-raised)] focus-within:border-[color-mix(in_srgb,var(--fl-accent)_55%,transparent)] p-2 pl-4 shadow-[var(--fl-shadow)] backdrop-blur">
          <textarea
            className="max-h-40 min-h-[24px] flex-1 fl-bare resize-none bg-transparent py-2 text-[15px] outline-none placeholder:text-[var(--fl-text-3)]"
            rows={1}
            placeholder="Ask Pitchfork…"
            value={draft}
            maxLength={8000}
            onChange={(e) => {
              setDraft(e.target.value)
              e.target.style.height = "auto"
              e.target.style.height = `${e.target.scrollHeight}px`
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
                e.preventDefault()
                send(draft)
              }
            }}
          />
          <button
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--fl-text)] text-[var(--fl-bg)] disabled:opacity-30"
            aria-label="Send"
            disabled={busy || !draft.trim()}
          >
            <Icon name="send" />
          </button>
        </div>
        <p className="fl-fine mt-2 text-center">Pitchfork can be wrong, and isn&apos;t medical advice.</p>
      </form>
    </div>
  )
}
