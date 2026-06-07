import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Privacy Policy | Personal OS",
}

export default function PrivacyPage() {
  return (
    <main className="max-w-3xl mx-auto px-6 py-20">
      <h1 className="text-3xl font-semibold text-[var(--deep-brown)] mb-8" style={{ fontFamily: "var(--font-display)" }}>
        Privacy Policy
      </h1>
      <div className="prose prose-sm text-[var(--mid-brown)] space-y-4">
        <p>Your data stays on your device and under your control. Personal OS does not sell or share your personal information.</p>
        <p>Health data is stored locally in SQLite databases on your machine. When using SaaS mode, data is encrypted in transit and at rest.</p>
        <p>This policy was last updated on {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}.</p>
      </div>
    </main>
  )
}
