"use client"

import { useEffect, useMemo, useState } from "react"
import { useQuery, useMutation } from "convex/react"
import { Check, Smartphone, Link2, AlertCircle, Loader2, X } from "lucide-react"
import { api } from "../../../convex/_generated/api"
import { PROVIDER_INFO } from "../../../convex/health/providers"
import { METRICS, defaultPriority, type MetricKey } from "../../../convex/health/metrics"

/**
 * Device & service connections.
 *
 * Every provider renders as the same card whether it arrives over OAuth or is
 * pushed from a phone — the transport is our problem, not the user's. The one
 * visible difference is what "connect" does, and the `pending` state a device
 * sits in until its first batch actually lands.
 *
 * Reads come through convex/react rather than a fetch route so status is live:
 * when the phone finally syncs, the card flips from pending to connected
 * without the user reloading.
 */

type Connection = {
  key: string
  label: string
  kind: "cloud" | "device"
  platform?: "ios" | "android"
  highlights: string[]
  status: string
  last_sync_at?: number
  last_error?: string
}

function relativeTime(ts?: number) {
  if (!ts) return null
  const mins = Math.round((Date.now() - ts) / 60000)
  if (mins < 1) return "just now"
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.round(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return `${Math.round(hrs / 24)}d ago`
}

const STATUS_STYLE: Record<string, { label: string; className: string }> = {
  connected: { label: "Connected", className: "bg-[var(--sage-low)] text-[#41553F]" },
  pending: { label: "Not finished", className: "bg-[var(--amber-low)] text-[#7A5227]" },
  error: { label: "Needs attention", className: "bg-[#F3D9D9] text-[#8C3B3B]" },
  disconnected: { label: "Not connected", className: "bg-[var(--bg-active)] text-[var(--dust)]" },
}

export default function ConnectionsPanel() {
  const providers = useQuery(api.health.connections.available) as Connection[] | undefined
  const connect = useMutation(api.health.connections.connect)
  const disconnect = useMutation(api.health.connections.disconnect)

  const [busy, setBusy] = useState<string | null>(null)
  const [deviceHelp, setDeviceHelp] = useState<Connection | null>(null)

  // The OAuth routes redirect back with ?error / ?connected / ?cancelled.
  // Without reading these, a failed link looked like nothing happened at all.
  const [notice, setNotice] = useState<{ tone: "error" | "ok"; text: string } | null>(null)

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const error = params.get("error")
    const connected = params.get("connected")
    const cancelled = params.get("cancelled")
    if (!error && !connected && !cancelled) return

    // Reading these during render instead would mean either touching `window`
    // on the server, or rendering null there and the banner here — a hydration
    // mismatch. A mount-time effect is the right tool; it runs once and the
    // params are cleared immediately after.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setNotice(
      error
        ? { tone: "error", text: error }
        : connected
          ? { tone: "ok", text: `${connected} connected.` }
          : { tone: "error", text: "Connection cancelled." },
    )

    // strip them so a refresh doesn't replay a stale message
    window.history.replaceState({}, "", window.location.pathname)
  }, [])

  const connected = useMemo(
    () => (providers ?? []).filter((p) => p.status === "connected"),
    [providers],
  )

  async function handleConnect(p: Connection) {
    setBusy(p.key)
    try {
      if (p.kind === "cloud") {
        // Records intent, then hands off to the provider. The callback route
        // completes the link with the external account id.
        await connect({ provider: p.key })
        window.location.href = `/api/health/oauth/${p.key}/start`
      } else {
        // Nothing to redirect to — the phone is the client. Mark it pending
        // and tell the user what to do next.
        await connect({ provider: p.key })
        setDeviceHelp(p)
      }
    } finally {
      setBusy(null)
    }
  }

  async function handleDisconnect(p: Connection) {
    setBusy(p.key)
    try {
      await disconnect({ provider: p.key })
    } finally {
      setBusy(null)
    }
  }

  if (providers === undefined) {
    return (
      <div className="flex items-center gap-2 py-16 justify-center text-[var(--dust)] text-[13px]">
        <Loader2 className="w-4 h-4 animate-spin" />
        Loading your connections…
      </div>
    )
  }

  return (
    <div className="space-y-10">
      {notice && (
        <div
          role="status"
          className={`rounded-[12px] border px-4 py-3 text-[13px] ${
            notice.tone === "error"
              ? "border-[#E0BDBD] bg-[#F7E9E9] text-[#8C3B3B]"
              : "border-[var(--sage-low)] bg-[var(--sage-low)]/40 text-[#41553F]"
          }`}
        >
          {notice.text}
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {providers.map((p) => {
          const status = STATUS_STYLE[p.status] ?? STATUS_STYLE.disconnected
          const isConnected = p.status === "connected"
          const isPending = p.status === "pending"

          return (
            <article
              key={p.key}
              className="rounded-[14px] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-5 flex flex-col gap-3 shadow-[var(--shadow-sm)]"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-[10px] bg-[var(--linen)] border border-[var(--border-subtle)] flex items-center justify-center">
                    {p.kind === "device" ? (
                      <Smartphone className="w-4 h-4 text-[var(--mid-brown)]" />
                    ) : (
                      <Link2 className="w-4 h-4 text-[var(--mid-brown)]" />
                    )}
                  </div>
                  <h3
                    className="text-[15px] font-semibold text-[var(--deep-brown)]"
                    style={{ fontFamily: "var(--font-display)" }}
                  >
                    {p.label}
                  </h3>
                </div>
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-[10px] uppercase tracking-[0.12em] ${status.className}`}
                >
                  {status.label}
                </span>
              </div>

              <p className="text-[12.5px] leading-relaxed text-[var(--mid-brown)] min-h-[2.5rem]">
                {p.highlights[0]}
              </p>

              {isConnected && p.last_sync_at && (
                <p className="text-[11px] text-[var(--dust)] flex items-center gap-1.5">
                  <Check className="w-3 h-3 text-[var(--sage)]" />
                  Synced {relativeTime(p.last_sync_at)}
                </p>
              )}

              {isPending && p.kind === "cloud" && (
                <p className="text-[11px] text-[var(--mid-brown)]">
                  You started this but it never completed — try connecting again.
                </p>
              )}

              {isPending && p.kind === "device" && (
                <p className="text-[11px] text-[var(--mid-brown)]">
                  {p.platform === "ios" ? (
                    <>
                      No data yet —{" "}
                      <button
                        type="button"
                        onClick={() =>
                          document
                            .getElementById("apple-health-import")
                            ?.scrollIntoView({ behavior: "smooth", block: "center" })
                        }
                        className="text-[var(--amber)] underline underline-offset-2"
                      >
                        import an export file
                      </button>{" "}
                      to fill it in now.
                    </>
                  ) : (
                    "No data yet — the companion app isn't available for Android yet."
                  )}
                </p>
              )}

              {p.status === "error" && p.last_error && (
                <p className="text-[11px] text-[#8C3B3B] flex items-start gap-1.5">
                  <AlertCircle className="w-3 h-3 mt-0.5 shrink-0" />
                  {p.last_error}
                </p>
              )}

              <div className="mt-auto pt-1">
                {isConnected || isPending ? (
                  <button
                    type="button"
                    onClick={() => handleDisconnect(p)}
                    disabled={busy === p.key}
                    className="text-[12px] text-[var(--mid-brown)] hover:text-[#8C3B3B] transition-colors disabled:opacity-50"
                  >
                    Disconnect
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => handleConnect(p)}
                    disabled={busy === p.key}
                    className="bg-[var(--deep-brown)] text-[var(--warm-white)] px-4 py-2 rounded-[10px] text-[12px] font-medium
                      hover:opacity-85 transition-all active:scale-[0.98] disabled:opacity-50 flex items-center gap-2"
                  >
                    {busy === p.key && <Loader2 className="w-3 h-3 animate-spin" />}
                    Connect
                  </button>
                )}
              </div>
            </article>
          )
        })}
      </div>

      {connected.length > 1 && <SourcePriority connected={connected} />}

      {deviceHelp && (
        <DeviceInstructions
          provider={deviceHelp}
          onClose={() => setDeviceHelp(null)}
          onImport={() => {
            setDeviceHelp(null)
            document
              .getElementById("apple-health-import")
              ?.scrollIntoView({ behavior: "smooth", block: "center" })
          }}
        />
      )}
    </div>
  )
}

/**
 * Which device wins when several report the same thing.
 *
 * Only shown for metrics more than one connected provider can actually supply
 * — asking someone to rank sources they don't own is noise. Setting a
 * preference re-resolves history immediately, because resolution happens at
 * read time.
 */
function SourcePriority({ connected }: { connected: Connection[] }) {
  const setPriority = useMutation(api.health.connections.setPriority)
  const [saving, setSaving] = useState<string | null>(null)

  const contested = useMemo(() => {
    const keys = connected.map((c) => c.key)
    const out: { metric: MetricKey; providers: string[] }[] = []

    for (const metric of Object.keys(METRICS) as MetricKey[]) {
      const suppliers = keys.filter((k) =>
        PROVIDER_INFO[k as keyof typeof PROVIDER_INFO]?.metrics.includes(metric),
      )
      if (suppliers.length > 1) out.push({ metric, providers: suppliers })
    }
    // the ones people actually care about, first
    const headline: MetricKey[] = ["sleep_duration", "steps", "resting_heart_rate", "hrv", "active_energy"]
    return out
      .filter((c) => headline.includes(c.metric))
      .sort((a, b) => headline.indexOf(a.metric) - headline.indexOf(b.metric))
  }, [connected])

  if (contested.length === 0) return null

  const label = (key: string) =>
    PROVIDER_INFO[key as keyof typeof PROVIDER_INFO]?.label ?? key

  async function choose(metric: MetricKey, provider: string) {
    setSaving(metric)
    try {
      // put the chosen source first, keep the sensible default order behind it
      const rest = defaultPriority(metric).filter((p) => p !== provider)
      await setPriority({ metric, priority: [provider, ...rest] })
    } finally {
      setSaving(null)
    }
  }

  return (
    <section className="rounded-[14px] border border-[var(--border-subtle)] bg-[var(--bg-elevated)] p-6">
      <h2
        className="text-[16px] font-semibold text-[var(--deep-brown)] mb-1"
        style={{ fontFamily: "var(--font-display)" }}
      >
        When devices disagree
      </h2>
      <p className="text-[12.5px] text-[var(--mid-brown)] mb-5 max-w-[46rem] leading-relaxed">
        More than one of your devices reports these. We never add them together —
        we pick one and show you which. Change the choice and your whole history
        updates.
      </p>

      <div className="space-y-3">
        {contested.map(({ metric, providers }) => (
          <div
            key={metric}
            className="flex flex-wrap items-center justify-between gap-3 py-2.5 border-t border-[var(--border-subtle)]"
          >
            <span className="text-[13px] text-[var(--deep-brown)] capitalize">
              {metric.replace(/_/g, " ")}
            </span>
            <div className="flex flex-wrap gap-1.5 items-center">
              {saving === metric && (
                <Loader2 className="w-3 h-3 animate-spin text-[var(--dust)]" />
              )}
              <PrioritySelect
                metric={metric}
                providers={providers}
                labelFor={label}
                onChoose={choose}
              />
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

function PrioritySelect({
  metric,
  providers,
  labelFor,
  onChoose,
}: {
  metric: MetricKey
  providers: string[]
  labelFor: (k: string) => string
  onChoose: (metric: MetricKey, provider: string) => void
}) {
  const current = useQuery(api.health.connections.priorityFor, { metric }) as
    | { priority: string[]; isDefault: boolean }
    | undefined

  // the winner is the first entry in the order that this user actually has
  const winner = current?.priority.find((p) => providers.includes(p)) ?? providers[0]

  return (
    <div className="flex gap-1.5 flex-wrap">
      {providers.map((p) => (
        <button
          key={p}
          type="button"
          onClick={() => onChoose(metric, p)}
          aria-pressed={p === winner}
          className={`px-3 py-1.5 rounded-full text-[11px] transition-colors border ${
            p === winner
              ? "bg-[var(--deep-brown)] text-[var(--warm-white)] border-[var(--deep-brown)]"
              : "bg-transparent text-[var(--mid-brown)] border-[var(--border-mid)] hover:border-[var(--amber)]"
          }`}
        >
          {labelFor(p)}
        </button>
      ))}
    </div>
  )
}

function DeviceInstructions({
  provider,
  onClose,
  onImport,
}: {
  provider: Connection
  onClose: () => void
  onImport: () => void
}) {
  const isIOS = provider.platform === "ios"

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-[rgba(40,32,15,0.35)] p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="device-help-title"
      onClick={onClose}
    >
      <div
        className="bg-[var(--bg-elevated)] rounded-[16px] p-7 max-w-[26rem] w-full shadow-[var(--shadow-md)] relative"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-4 right-4 text-[var(--dust)] hover:text-[var(--deep-brown)]"
        >
          <X className="w-4 h-4" />
        </button>

        <h2
          id="device-help-title"
          className="text-[18px] font-semibold text-[var(--deep-brown)] mb-2"
          style={{ fontFamily: "var(--font-display)" }}
        >
          Two ways to bring {provider.label} in
        </h2>
        <p className="text-[13px] text-[var(--mid-brown)] leading-relaxed mb-5">
          {provider.label} data lives on your device — there&rsquo;s no server a
          browser can ask. So either hand us a file, or let the app do it
          continuously.
        </p>

        {/* The import works today; the app does not exist yet. Lead with the
            one the user can actually complete right now. */}
        {isIOS && (
          <div className="rounded-[12px] border border-[var(--border-mid)] bg-[var(--linen)] p-4 mb-4">
            <p className="text-[11px] uppercase tracking-[0.14em] text-[var(--amber)] mb-1.5">
              Available now
            </p>
            <h3 className="text-[14px] font-medium text-[var(--deep-brown)] mb-1.5">
              Import an export file
            </h3>
            <p className="text-[12px] text-[var(--mid-brown)] leading-relaxed mb-3">
              On your iPhone: Health → your profile → Export All Health Data.
              Send the zip here and drop it in — you&rsquo;ll get your full
              history without installing anything.
            </p>
            <button
              type="button"
              onClick={onImport}
              className="bg-[var(--deep-brown)] text-[var(--warm-white)] px-4 py-2 rounded-[10px] text-[12px] font-medium hover:opacity-85 transition-all active:scale-[0.98]"
            >
              Go to import
            </button>
          </div>
        )}

        <div className="rounded-[12px] border border-dashed border-[var(--border-mid)] p-4">
          <p className="text-[11px] uppercase tracking-[0.14em] text-[var(--dust)] mb-1.5">
            Coming soon
          </p>
          <h3 className="text-[14px] font-medium text-[var(--deep-brown)] mb-1.5">
            The Personal OS app
          </h3>
          <p className="text-[12px] text-[var(--mid-brown)] leading-relaxed">
            Sign in once, allow health access, and it syncs on its own — no
            re-exporting. It isn&rsquo;t on the {isIOS ? "App Store" : "Play Store"}{" "}
            yet; this card will switch to Connected by itself once data starts
            arriving.
          </p>
        </div>
      </div>
    </div>
  )
}
