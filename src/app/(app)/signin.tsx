"use client"
import { useState } from "react"
import { useAuthActions } from "@convex-dev/auth/react"
import { messageOf } from "@/web/errors"
import { SITE_URL } from "@/web/convexUrl"

/**
 * Email and password, the one way in that works from a browser. Google, Facebook and Apple only
 * return to the phone app (safeRedirect in convex/auth.ts), so they stay there for now.
 */
export function SignIn() {
  const { signIn } = useAuthActions()
  const [flow, setFlow] = useState<"signIn" | "signUp">("signIn")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState("")

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const form = new FormData(e.currentTarget)
    form.set("flow", flow)
    setBusy(true)
    setError("")
    try {
      await signIn("password", form)
    } catch (err) {
      const message = messageOf(err)
      setError(
        flow === "signUp" && /already exists/i.test(message)
          ? "There's already an account with that email. Sign in instead."
          : flow === "signIn" && /InvalidAccountId|InvalidSecret|Invalid credentials|don't match/i.test(message)
            ? "That email and password don't match."
            : message,
      )
      setBusy(false)
    }
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-sm flex-col justify-center px-6 py-16">
      <div className="fl-in">
        <h1 className="fl-serif text-[52px] leading-none tracking-tight">Forklore</h1>
        <p className="fl-lede mt-4">What to eat next, from your own numbers and the food where you live.</p>
      </div>

      <form onSubmit={submit} className="fl-in mt-10 flex flex-col gap-3" style={{ animationDelay: "80ms" }}>
        {flow === "signUp" && (
          <input className="fl-input" name="name" placeholder="Your name" autoComplete="name" maxLength={80} />
        )}
        <input className="fl-input" name="email" type="email" placeholder="Email" autoComplete="email" required />
        <input
          className="fl-input"
          name="password"
          type="password"
          placeholder="Password"
          autoComplete={flow === "signUp" ? "new-password" : "current-password"}
          minLength={flow === "signUp" ? 8 : undefined}
          required
        />
        {error && <p className="fl-error">{error}</p>}
        <button className="fl-btn wide mt-2" disabled={busy}>
          {busy ? "One moment…" : flow === "signIn" ? "Sign in" : "Create account"}
        </button>
      </form>

      <button
        className="mt-5 text-sm text-[var(--fl-text-2)]"
        onClick={() => {
          setFlow(flow === "signIn" ? "signUp" : "signIn")
          setError("")
        }}
      >
        {flow === "signIn" ? "New here? Create an account" : "Already have an account? Sign in"}
      </button>

      <p className="fl-fine mt-10">
        Signed up on the phone with Google, Facebook or Apple? Those sign-ins only work in the iOS app for now. By
        continuing you agree to the{" "}
        <a className="fl-link" href={`${SITE_URL}/terms`} target="_blank" rel="noreferrer">
          terms
        </a>{" "}
        and{" "}
        <a className="fl-link" href={`${SITE_URL}/privacy`} target="_blank" rel="noreferrer">
          privacy policy
        </a>
        .
      </p>
    </main>
  )
}
