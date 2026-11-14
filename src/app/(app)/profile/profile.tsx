"use client"
import { useState } from "react"
import { useMutation, useQuery } from "convex/react"
import { useAuthActions } from "@convex-dev/auth/react"
import { api } from "../../../../convex/_generated/api"
import { SITE_URL } from "@/web/convexUrl"
import { messageOf } from "@/web/errors"
import { CHATS_KEY, CURRENT_KEY } from "@/web/pitchfork"
import { COUNTRY_KEY } from "@/web/country"
import { Header, Page } from "../shell"

/** What this browser keeps, cleared when the account goes so the next person starts fresh. */
const LOCAL_KEYS = [CHATS_KEY, CURRENT_KEY, COUNTRY_KEY, "fl.meals", "fl.consults"]

function forgetLocal() {
  for (const key of LOCAL_KEYS) {
    try {
      window.localStorage.removeItem(key)
    } catch {
      // Nothing was stored.
    }
  }
}

/** Account details, legal pages, signing out and deleting the account. */
export function Profile() {
  const me = useQuery(api.users.me)
  const { signOut } = useAuthActions()

  return (
    <Page>
      <Header kicker="Profile" title={me?.name || "Your account"} lede={me?.email ?? undefined} />

      {me && <Name current={me.name ?? ""} />}

      <section className="mt-10">
        <p className="fl-kicker">About</p>
        <a className="fl-row" href={`${SITE_URL}/privacy`} target="_blank" rel="noreferrer">
          <span className="flex-1">Privacy</span>
          <span className="text-[var(--fl-text-3)]">↗</span>
        </a>
        <a className="fl-row" href={`${SITE_URL}/terms`} target="_blank" rel="noreferrer">
          <span className="flex-1">Terms</span>
          <span className="text-[var(--fl-text-3)]">↗</span>
        </a>
        <p className="fl-fine mt-4">
          Apple Health sync, notifications, video calls and applying as a practitioner are in the iOS app. Chats and meal ideas
          on the web are kept in this browser only.
        </p>
      </section>

      <section className="mt-10 flex flex-col gap-3">
        <button className="fl-btn ghost wide" onClick={() => void signOut()}>
          Log out
        </button>
        <Delete
          onDeleted={async () => {
            forgetLocal()
            await signOut()
          }}
        />
      </section>
    </Page>
  )
}

function Name({ current }: { current: string }) {
  const setName = useMutation(api.users.setName)
  const [name, setValue] = useState(current)
  const [note, setNote] = useState("")
  const changed = name.trim() !== current

  return (
    <form
      className="mt-8"
      onSubmit={async (e) => {
        e.preventDefault()
        setNote("")
        try {
          await setName({ name })
          setNote("Saved.")
        } catch (err) {
          setNote(messageOf(err))
        }
      }}
    >
      <label className="fl-kicker" htmlFor="name">
        Name
      </label>
      <div className="mt-2 flex gap-2">
        <input
          id="name"
          className="fl-input"
          value={name}
          maxLength={80}
          autoComplete="name"
          onChange={(e) => {
            setValue(e.target.value)
            setNote("")
          }}
        />
        <button className="fl-btn ghost shrink-0" disabled={!changed}>
          Save
        </button>
      </div>
      {note && <p className="fl-note mt-2">{note}</p>}
    </form>
  )
}

/** Deleting the account: everything it owns on the server goes, so it asks for the word first. */
function Delete({ onDeleted }: { onDeleted: () => Promise<void> }) {
  const remove = useMutation(api.users.deleteAccount)
  const [asking, setAsking] = useState(false)
  const [word, setWord] = useState("")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")

  if (!asking) {
    return (
      <button className="fl-btn danger wide" onClick={() => setAsking(true)}>
        Delete account
      </button>
    )
  }

  return (
    <div className="fl-plate">
      <p className="fl-serif-body text-[17px]">
        This deletes your account, your synced health data, your consultations and anything you wrote. It can&apos;t be
        undone.
      </p>
      <label className="fl-note mt-4 block" htmlFor="confirm">
        Type DELETE to confirm.
      </label>
      <input id="confirm" className="fl-input mt-2" value={word} onChange={(e) => setWord(e.target.value)} />
      {error && <p className="fl-error mt-2">{error}</p>}
      <div className="mt-3 flex gap-2">
        <button className="fl-btn ghost" onClick={() => setAsking(false)} disabled={busy}>
          Cancel
        </button>
        <button
          className="fl-btn danger"
          disabled={busy || word.trim() !== "DELETE"}
          onClick={async () => {
            setBusy(true)
            setError("")
            try {
              await remove()
              await onDeleted()
            } catch (err) {
              setError(messageOf(err))
              setBusy(false)
            }
          }}
        >
          Delete for good
        </button>
      </div>
    </div>
  )
}
