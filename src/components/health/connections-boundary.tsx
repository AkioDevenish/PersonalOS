"use client"

import React from "react"
import { AlertCircle, RefreshCw } from "lucide-react"

/**
 * Convex's useQuery throws on error rather than returning one, so without a
 * boundary any backend failure — an expired session, a network blip, a
 * function that isn't deployed — replaces the entire route with a crash
 * screen. Contain it here so the page chrome survives and the user gets
 * something they can act on.
 */

type Props = { children: React.ReactNode }
type State = { error: Error | null }

export default class ConnectionsBoundary extends React.Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  render() {
    const { error } = this.state
    if (!error) return this.props.children

    // "Could not find public function" means the health/* modules exist in the
    // repo but were never pushed — by far the likeliest cause in development,
    // and worth naming precisely instead of showing a generic failure.
    const notDeployed = /could not find (public )?function/i.test(error.message)
    const notAuthed = /not authenticated/i.test(error.message)

    return (
      <div className="rounded-[14px] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-8 text-center">
        <div className="w-10 h-10 rounded-[12px] bg-[#F3D9D9] flex items-center justify-center mx-auto mb-4">
          <AlertCircle className="w-5 h-5 text-[#8C3B3B]" />
        </div>

        <h2
          className="text-[17px] font-semibold text-[var(--deep-brown)] mb-2"
          style={{ fontFamily: "var(--font-display)" }}
        >
          Couldn&rsquo;t load your connections
        </h2>

        <p className="text-[13px] text-[var(--mid-brown)] max-w-[30rem] mx-auto leading-relaxed mb-5">
          {notDeployed
            ? "The health functions haven't been deployed to Convex yet. Run npx convex dev once to push them."
            : notAuthed
              ? "Your session isn't reaching Convex. Sign out and back in — if it persists, the Clerk JWT template may need configuring."
              : "Something went wrong talking to the server."}
        </p>

        <button
          type="button"
          onClick={() => this.setState({ error: null })}
          className="inline-flex items-center gap-2 bg-[var(--deep-brown)] text-[var(--warm-white)] px-4 py-2 rounded-[10px] text-[12px] font-medium hover:opacity-85 transition-all active:scale-[0.98]"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          Try again
        </button>

        <details className="mt-5 text-left max-w-[30rem] mx-auto">
          <summary className="text-[11px] text-[var(--dust)] cursor-pointer">
            Technical detail
          </summary>
          <pre className="mt-2 text-[10.5px] text-[var(--mid-brown)] whitespace-pre-wrap break-words bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] p-3">
            {error.message}
          </pre>
        </details>
      </div>
    )
  }
}
