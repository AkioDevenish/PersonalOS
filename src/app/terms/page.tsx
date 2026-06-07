import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Terms of Service | Personal OS",
}

export default function TermsPage() {
  return (
    <main className="max-w-3xl mx-auto px-6 py-20">
      <h1 className="text-3xl font-semibold text-[var(--deep-brown)] mb-8" style={{ fontFamily: "var(--font-display)" }}>
        Terms of Service
      </h1>
      <div className="prose prose-sm text-[var(--mid-brown)] space-y-4">
        <p>Personal OS is provided &quot;as is&quot; without warranty of any kind. You are responsible for your own data and how you use this tool.</p>
        <p>By using this software, you agree that the authors are not liable for any claims or damages arising from its use.</p>
        <p>These terms were last updated on {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}.</p>
      </div>
    </main>
  )
}
