"use client"
import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { useAction, useMutation, useQuery } from "convex/react"
import type { FunctionReturnType } from "convex/server"
import { api } from "../../../../convex/_generated/api"
import { update, useStored } from "@/web/store"
import { countries, countryName, useCountry } from "@/web/country"
import { messageOf } from "@/web/errors"
import { CHATS_KEY, CURRENT_KEY, MAX_CHATS, NO_CHATS, clean, contextFor, newId, titleOf, type Chat } from "@/web/pitchfork"
import { Header, Page } from "../shell"

const MEALS = ["breakfast", "lunch", "dinner", "snack"] as const
type Meal = (typeof MEALS)[number]

type Idea = { id: string; meal: Meal; question: string; text: string; at: number }
const IDEAS_KEY = "fl.meals"
const NO_IDEAS: Idea[] = []

/** The meal that fits the hour, so the button is usually right before anyone touches it. */
function mealNow(): Meal {
  const h = new Date().getHours()
  if (h < 11) return "breakfast"
  if (h < 15) return "lunch"
  if (h < 21) return "dinner"
  return "snack"
}

/**
 * Meals, on the web. The phone writes ideas with Apple's on-device model when it can; a browser
 * can't, so this asks Pitchfork, which reads the person's synced glucose, sleep and activity.
 */
export function Meals() {
  const router = useRouter()
  const ask = useAction(api.health.pitchfork.reply)
  const [country, setCountry] = useCountry()
  const [meal, setMeal] = useState<Meal>(mealNow)
  const [ideas] = useStored<Idea[]>(IDEAS_KEY, NO_IDEAS)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")

  const book = useQuery(api.health.cuisine.forCountry, country ? { country } : "skip")
  const prepare = useMutation(api.health.cuisine.prepare)

  // A country nobody has cooked in yet gets its dish list written in the background.
  useEffect(() => {
    if (country) prepare({ country }).catch(() => {})
  }, [country, prepare])

  async function suggest() {
    setBusy(true)
    setError("")
    const place = country ? ` I cook and shop in ${countryName(country)}.` : ""
    const dishes = book?.canon.slice(0, 30) ?? []
    const known = dishes.length > 0 ? ` Dishes people eat here include: ${dishes.join(", ")}.` : ""
    const question = `Suggest a ${meal} for me that fits my recent numbers.${place}`
    try {
      const answer = await ask({
        lines: [{ who: "you", text: `${question}${known} Check my recent glucose, carbs, sleep and activity first.` }],
        context: contextFor(country),
      })
      const idea: Idea = { id: newId(), meal, question, text: clean(answer.text), at: Date.now() }
      update<Idea[]>(IDEAS_KEY, NO_IDEAS, (all) => [idea, ...all].slice(0, 20))
    } catch (err) {
      setError(messageOf(err))
    } finally {
      setBusy(false)
    }
  }

  /** Carries an idea into a Pitchfork chat, to ask about it further. */
  function talkAbout(idea: Idea) {
    const lines: Chat["lines"] = [
      { who: "you", text: idea.question },
      { who: "assistant", text: idea.text },
    ]
    const chat: Chat = { id: newId(), title: titleOf(lines), lines, updated: Date.now() }
    update<Chat[]>(CHATS_KEY, NO_CHATS, (all) => [chat, ...all].slice(0, MAX_CHATS))
    update<string>(CURRENT_KEY, "", () => chat.id)
    router.push("/pitchfork")
  }

  const latest = ideas[0]

  return (
    <Page>
      <Header
        kicker="Nutrition"
        title="What to eat next."
        lede={
          country
            ? `Based on your recent glucose, sleep and activity, with food from ${countryName(country)}.`
            : "Based on your recent glucose, sleep and activity."
        }
      />

      <label className="fl-row mt-6 cursor-pointer">
        <span className="fl-kicker shrink-0">Cooking in</span>
        <select
          className="fl-serif ml-auto min-w-0 cursor-pointer appearance-none bg-transparent text-right text-[19px] outline-none"
          value={country}
          onChange={(e) => setCountry(e.target.value)}
        >
          <option value="">Anywhere</option>
          {countries().map((c) => (
            <option key={c.code} value={c.code}>
              {c.name}
            </option>
          ))}
        </select>
        <span className="fl-serif text-[var(--fl-text-3)]">›</span>
      </label>

      <div className="mt-5 flex flex-wrap gap-2" role="group" aria-label="Which meal">
        {MEALS.map((m) => (
          <button key={m} className="fl-pill" aria-pressed={m === meal} onClick={() => setMeal(m)}>
            {m}
          </button>
        ))}
      </div>

      <button className="fl-btn wide mt-5" onClick={suggest} disabled={busy}>
        {busy ? "Thinking…" : `Suggest ${meal}`}
      </button>
      <p className="fl-note mt-3">
        Pitchfork writes these on the web. It looks at what your phone has synced and sends it to its AI to answer.
      </p>
      {error && <p className="fl-error mt-3">{error}</p>}

      {busy && (
        <div className="fl-plate mt-5 space-y-3" aria-hidden="true">
          {[90, 75, 82, 60].map((w, i) => (
            <div key={i} className="h-3 animate-pulse rounded-full bg-[var(--fl-line)]" style={{ width: `${w}%` }} />
          ))}
        </div>
      )}

      {latest && !busy && (
        <article className="fl-plate fl-in mt-5" key={latest.id}>
          <p className="fl-kicker">{latest.meal}</p>
          <p className="fl-serif-body mt-2 whitespace-pre-wrap text-[18px] leading-relaxed">{latest.text}</p>
          <button className="fl-btn small ghost mt-4" onClick={() => talkAbout(latest)}>
            Ask Pitchfork about this
          </button>
        </article>
      )}

      {country && <Dishes country={country} book={book} />}

      {ideas.length > 1 && <Recent ideas={ideas.slice(1)} />}

      <p className="fl-fine mt-10">
        Meal ideas, not medical advice. If your numbers worry you, talk to a nutritionist or your doctor.
      </p>
    </Page>
  )
}

type Book = FunctionReturnType<typeof api.health.cuisine.forCountry>

/** The country's dish list: written from Wikipedia, plus what people add. */
function Dishes({ country, book }: { country: string; book: Book | undefined }) {
  const add = useMutation(api.health.cuisine.suggest)
  const hide = useMutation(api.health.cuisine.reject)
  const [name, setName] = useState("")
  const [error, setError] = useState("")
  const [showAll, setShowAll] = useState(false)

  if (!book) return null
  const shown = showAll ? book.all : book.all.slice(0, 18)

  async function run(fn: () => Promise<unknown>) {
    setError("")
    try {
      await fn()
    } catch (err) {
      setError(messageOf(err))
    }
  }

  return (
    <section className="mt-10">
      <div className="flex items-baseline justify-between">
        <p className="fl-kicker">Food from {countryName(country)}</p>
        {book.generating && <p className="fl-fine">Writing the list…</p>}
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        {shown.map((d) => (
          <span key={d.key} className="fl-chip">
            {d.dish}
            {d.votes > 0 && <span className="fl-fine">{d.votes}</span>}
            {d.mine ? (
              <button title="Take back your vote" onClick={() => run(() => add({ country, dish: d.dish }))}>
                ×
              </button>
            ) : (
              !d.written || book.generated ? (
                <button title="Not eaten here" onClick={() => run(() => hide({ country, dish: d.dish }))}>
                  ×
                </button>
              ) : null
            )}
          </span>
        ))}
      </div>
      {book.all.length > 18 && (
        <button className="fl-fine mt-3 underline" onClick={() => setShowAll(!showAll)}>
          {showAll ? "Show fewer" : `Show all ${book.all.length}`}
        </button>
      )}
      <form
        className="mt-4 flex gap-2"
        onSubmit={(e) => {
          e.preventDefault()
          const dish = name.trim()
          if (!dish) return
          run(async () => {
            await add({ country, dish })
            setName("")
          })
        }}
      >
        <input
          className="fl-input"
          placeholder="Add a dish people eat here"
          value={name}
          maxLength={60}
          onChange={(e) => setName(e.target.value)}
        />
        <button className="fl-btn ghost shrink-0" disabled={!name.trim()}>
          Add
        </button>
      </form>
      {error && <p className="fl-error mt-2">{error}</p>}
    </section>
  )
}

function Recent({ ideas }: { ideas: Idea[] }) {
  return (
    <section className="mt-10">
      <div className="flex items-baseline justify-between">
        <p className="fl-kicker">Recently suggested</p>
        <button className="fl-fine underline" onClick={() => update<Idea[]>(IDEAS_KEY, NO_IDEAS, (all) => all.slice(0, 1))}>
          Clear
        </button>
      </div>
      {ideas.map((idea) => (
        <div key={idea.id} className="border-b border-[var(--fl-line)] py-4">
          <div className="flex items-baseline justify-between">
            <p className="fl-kicker">
              {idea.meal} ·{" "}
              {new Date(idea.at).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })}
            </p>
            <button
              className="fl-fine hover:text-[var(--fl-danger)]"
              onClick={() => update<Idea[]>(IDEAS_KEY, NO_IDEAS, (all) => all.filter((i) => i.id !== idea.id))}
            >
              Delete
            </button>
          </div>
          <p className="fl-serif-body mt-2 whitespace-pre-wrap text-[16px] leading-relaxed">{idea.text}</p>
        </div>
      ))}
    </section>
  )
}
