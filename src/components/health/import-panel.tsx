"use client"

import { useRef, useState } from "react"
import { Upload, Check, AlertCircle, Loader2 } from "lucide-react"

/**
 * Apple Health file import — the no-app path.
 *
 * Apple Health has no server API, so a browser cannot reach it live. But the
 * Health app can export everything to a zip, and that zip can be dropped here
 * from any machine. It parses locally and uploads only the daily rollup, so a
 * PC user gets years of history without installing anything.
 *
 * Snapshot, not a live feed: re-export to refresh, or install the app for
 * continuous sync.
 */

type Phase =
  | { state: "idle" }
  | { state: "parsing"; label: string; pct: number | null; records: number }
  | { state: "uploading"; sent: number; total: number }
  | { state: "done"; inserted: number; updated: number; days: number; skipped: number }
  | { state: "error"; message: string }

const BATCH = 500

export default function ImportPanel() {
  const [phase, setPhase] = useState<Phase>({ state: "idle" })
  const [dragging, setDragging] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  async function handleFile(file: File) {
    setPhase({ state: "parsing", label: "Opening export…", pct: null, records: 0 })

    const worker = new Worker(
      new URL("../../workers/apple-export.worker.ts", import.meta.url),
    )

    worker.onmessage = async (event) => {
      const msg = event.data

      if (msg.kind === "progress") {
        setPhase({
          state: "parsing",
          label: msg.phase,
          pct: msg.pct,
          records: msg.recordsSeen,
        })
        return
      }

      if (msg.kind === "error") {
        setPhase({ state: "error", message: msg.message })
        worker.terminate()
        return
      }

      // done — upload in batches the API will accept
      const samples = msg.samples as {
        metric: string
        value: number
        unit: string
        recorded_at: number
      }[]
      worker.terminate()

      if (samples.length === 0) {
        setPhase({ state: "error", message: "No supported health records found in that export." })
        return
      }

      let inserted = 0
      let updated = 0
      const days = new Set(samples.map((s) => s.recorded_at)).size

      try {
        for (let i = 0; i < samples.length; i += BATCH) {
          const batch = samples.slice(i, i + BATCH)
          setPhase({ state: "uploading", sent: i, total: samples.length })

          const res = await fetch("/api/health/ingest", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              provider: "apple_health",
              samples: batch,
              timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            }),
          })

          const body = await res.json().catch(() => null)
          if (!res.ok || !body?.success) {
            throw new Error(body?.error ?? `Upload failed (${res.status})`)
          }
          inserted += body.inserted ?? 0
          updated += body.updated ?? 0
        }

        setPhase({ state: "done", inserted, updated, days, skipped: msg.skipped })
      } catch (error) {
        setPhase({
          state: "error",
          message: error instanceof Error ? error.message : "Upload failed",
        })
      }
    }

    worker.postMessage({
      file,
      timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    })
  }

  const busy = phase.state === "parsing" || phase.state === "uploading"

  return (
    <section
      id="apple-health-import"
      className="rounded-[14px] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-6 scroll-mt-8"
    >
      <h2
        className="text-[16px] font-semibold text-[var(--deep-brown)] mb-1"
        style={{ fontFamily: "var(--font-display)" }}
      >
        Import from Apple Health
      </h2>
      <p className="text-[12.5px] text-[var(--mid-brown)] mb-5 max-w-[46rem] leading-relaxed">
        No iPhone app needed. On your phone open Health → your profile →{" "}
        <strong className="font-medium text-[var(--deep-brown)]">Export All Health Data</strong>,
        send the zip to this computer, and drop it below. It&rsquo;s read here in
        your browser — the file itself never leaves this machine.
      </p>

      <div
        onDragOver={(e) => {
          e.preventDefault()
          if (!busy) setDragging(true)
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault()
          setDragging(false)
          if (busy) return
          const file = e.dataTransfer.files?.[0]
          if (file) handleFile(file)
        }}
        onClick={() => !busy && inputRef.current?.click()}
        role="button"
        tabIndex={busy ? -1 : 0}
        onKeyDown={(e) => {
          if (!busy && (e.key === "Enter" || e.key === " ")) inputRef.current?.click()
        }}
        aria-label="Choose an Apple Health export file"
        className={`rounded-[12px] border border-dashed p-8 text-center transition-colors ${
          busy
            ? "border-[var(--border-subtle)] cursor-default"
            : dragging
              ? "border-[var(--amber)] bg-[var(--bg-hover)] cursor-pointer"
              : "border-[var(--border-mid)] hover:border-[var(--amber)] cursor-pointer"
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept=".zip,.xml"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) handleFile(file)
            e.target.value = ""
          }}
        />

        {phase.state === "idle" && (
          <>
            <Upload className="w-5 h-5 text-[var(--dust)] mx-auto mb-3" />
            <p className="text-[13px] text-[var(--deep-brown)]">
              Drop <code className="text-[12px]">export.zip</code> here, or click to choose
            </p>
            <p className="text-[11px] text-[var(--dust)] mt-1.5">
              Large exports are fine — nothing is uploaded but the daily summary
            </p>
          </>
        )}

        {phase.state === "parsing" && (
          <>
            <Loader2 className="w-5 h-5 text-[var(--amber)] mx-auto mb-3 animate-spin" />
            <p className="text-[13px] text-[var(--deep-brown)]">{phase.label}</p>
            <p className="text-[11px] text-[var(--dust)] mt-1.5">
              {phase.records.toLocaleString()} records read
              {phase.pct !== null && ` · ${phase.pct}%`}
            </p>
          </>
        )}

        {phase.state === "uploading" && (
          <>
            <Loader2 className="w-5 h-5 text-[var(--amber)] mx-auto mb-3 animate-spin" />
            <p className="text-[13px] text-[var(--deep-brown)]">Saving to your ledger…</p>
            <p className="text-[11px] text-[var(--dust)] mt-1.5">
              {phase.sent.toLocaleString()} of {phase.total.toLocaleString()}
            </p>
          </>
        )}

        {phase.state === "done" && (
          <>
            <Check className="w-5 h-5 text-[var(--sage)] mx-auto mb-3" />
            <p className="text-[13px] text-[var(--deep-brown)]">
              Imported {phase.inserted.toLocaleString()} measurements
              {phase.updated > 0 && `, updated ${phase.updated.toLocaleString()}`}
            </p>
            <p className="text-[11px] text-[var(--dust)] mt-1.5">
              Across {phase.days.toLocaleString()} days
              {phase.skipped > 0 && ` · ${phase.skipped.toLocaleString()} unsupported records skipped`}
            </p>
          </>
        )}

        {phase.state === "error" && (
          <>
            <AlertCircle className="w-5 h-5 text-[#8C3B3B] mx-auto mb-3" />
            <p className="text-[13px] text-[#8C3B3B]">{phase.message}</p>
            <p className="text-[11px] text-[var(--dust)] mt-1.5">Click to try another file</p>
          </>
        )}
      </div>
    </section>
  )
}
