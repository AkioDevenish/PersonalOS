"use client"
import { messageOf } from "@/web/errors"

/** A page whose data couldn't load, such as a consultation that isn't yours or a dropped connection. */
export default function AppError({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <main className="mx-auto max-w-md px-6 py-24 text-center">
      <h1 className="fl-serif text-[28px]">That didn&apos;t load.</h1>
      <p className="fl-note mt-3">{messageOf(error)}</p>
      <button className="fl-btn mt-6" onClick={reset}>
        Try again
      </button>
    </main>
  )
}
