import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft } from "lucide-react"
import ConnectionsPanel from "@/components/health/connections-panel"
import ConnectionsBoundary from "@/components/health/connections-boundary"
import ImportPanel from "@/components/health/import-panel"

export const metadata: Metadata = {
  title: "Connections | Personal OS",
}

export default function ConnectionsPage() {
  return (
    <div className="min-h-screen bg-[var(--bg-base)] px-5 md:px-8 py-8">
      <div className="max-w-6xl mx-auto">
        <Link
          href="/hub"
          className="inline-flex items-center gap-1.5 text-[12px] text-[var(--mid-brown)] hover:text-[var(--deep-brown)] transition-colors mb-6"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          Back to hub
        </Link>

        <header className="mb-8">
          <h1
            className="text-[26px] font-semibold text-[var(--deep-brown)]"
            style={{ fontFamily: "var(--font-display)" }}
          >
            Connections
          </h1>
          <p className="text-[13px] text-[var(--mid-brown)] mt-1.5 max-w-[42rem] leading-relaxed">
            Link a device or service once and it keeps feeding your ledger on its
            own. Everything stays read-only — Personal OS never writes back to
            them.
          </p>
        </header>

        <ConnectionsBoundary>
          <ConnectionsPanel />
        </ConnectionsBoundary>

        <div className="mt-10">
          <ImportPanel />
        </div>
      </div>
    </div>
  )
}
