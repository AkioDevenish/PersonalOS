"use client"

import type { CSSProperties } from "react"

const ORBITS = [
  { size: "min(86vw, 980px)", duration: "38s", tilt: "68deg", dot: "#2f2d29", delay: "-4s" },
  { size: "min(72vw, 780px)", duration: "30s", tilt: "62deg", dot: "#8f8170", delay: "-12s" },
  { size: "min(56vw, 620px)", duration: "24s", tilt: "74deg", dot: "#c2b8aa", delay: "-7s" },
]

export function HeroBackground() {
  return (
    <div className="hero-studio-bg" aria-hidden>
      <div className="hero-grain" />

      <div className="hero-orbit-field">
        {ORBITS.map((orbit, index) => (
          <div
            key={orbit.duration}
            className="hero-orbit"
            style={
              {
                "--orbit-size": orbit.size,
                "--orbit-duration": orbit.duration,
                "--orbit-tilt": orbit.tilt,
                "--orbit-dot": orbit.dot,
                "--orbit-delay": orbit.delay,
                "--orbit-offset": `${index * 11}deg`,
            } as CSSProperties
            }
          >
            <span />
          </div>
        ))}
      </div>

      <div className="hero-hand-watch">
        <div className="hero-hand">
          <span className="finger finger-index" />
          <span className="finger finger-middle" />
          <span className="finger finger-ring" />
          <span className="finger finger-little" />
          <span className="thumb" />
          <span className="palm" />
          <span className="wrist" />
        </div>

        <div className="hero-watch">
          <div className="watch-crown" />
          <div className="watch-face">
            <span className="watch-marker marker-12" />
            <span className="watch-marker marker-3" />
            <span className="watch-marker marker-6" />
            <span className="watch-marker marker-9" />
            <span className="watch-hand hour" />
            <span className="watch-hand minute" />
            <span className="watch-pin" />
          </div>
        </div>
      </div>

      <div className="hero-side-note left">
        <span>Interactive</span>
        <p>Hover the system and watch the signal settle.</p>
      </div>
      <div className="hero-side-note right">
        <span>Local first</span>
        <p>Private rhythms, visible patterns, calmer decisions.</p>
      </div>
    </div>
  )
}
