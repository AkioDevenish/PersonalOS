"use client"

import dynamic from "next/dynamic"

const FlowWatch = dynamic(
  () => import("@/components/hero/flow-watch").then((m) => m.FlowWatch),
  {
    ssr: false,
    loading: () => (
      <div className="absolute inset-0 flex items-center justify-center" aria-hidden>
        <div className="w-48 h-48 rounded-full border border-[var(--border-subtle)] animate-pulse" />
      </div>
    ),
  }
)

export function HeroSection() {
  return (
    <section className="relative min-h-[100svh] flex items-center justify-center overflow-hidden pt-20">
      <div
        className="absolute inset-0 pointer-events-none"
        aria-hidden
        style={{
          background:
            "radial-gradient(ellipse 70% 55% at 50% 45%, rgba(222,201,174,0.22) 0%, transparent 65%)",
        }}
      />

      <div className="relative z-10 w-full max-w-5xl mx-auto px-5 md:px-8">
        <div className="relative mx-auto w-full max-w-[min(92vw,520px)] aspect-square">
          <FlowWatch />

          <h1
            className="absolute z-20 font-display font-bold tracking-tight text-[var(--deep-brown)]
              text-[clamp(2rem,6vw,3.25rem)] leading-none
              left-[8%] top-[14%] md:left-[10%] md:top-[12%]
              pointer-events-none select-none"
          >
            Personal OS
          </h1>
        </div>
      </div>
    </section>
  )
}
