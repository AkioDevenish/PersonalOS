"use client"

import { useEffect, useRef } from "react"
import Link from "next/link"
import { ArrowRight } from "lucide-react"
import s from "./story.module.css"
import sh from "../shared.module.css"

const clamp = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v))
const norm = (p: number, a: number, b: number) => clamp((p - a) / (b - a), 0, 1)
const easeOut = (t: number) => 1 - Math.pow(1 - t, 3)
const easeInOut = (t: number) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2)

type ChapterId = "time" | "vitality" | "connection" | "growth"

const CHAPTERS: {
  id: ChapterId
  numeral: string
  label: string
  title: string
  paras: string[]
  copySide: "copyLeft" | "copyRight"
}[] = [
  {
    id: "time",
    numeral: "I",
    label: "Chapter I · The first currency",
    title: "Time",
    paras: [
      "Minted once, spent always. The watch does not tick to remind you of what is left — it ticks to remind you that it is leaving.",
      "Personal OS keeps the ledger of your hours, so every one of them is spent on purpose.",
    ],
    copySide: "copyLeft",
  },
  {
    id: "vitality",
    numeral: "II",
    label: "Chapter II · The second currency",
    title: "Vitality",
    paras: [
      "The heart keeps the only honest books: a hundred thousand entries a day, every one paid in advance.",
      "Health is the exchange rate on everything else you own. Track it like it matters — because it does.",
    ],
    copySide: "copyRight",
  },
  {
    id: "connection",
    numeral: "III",
    label: "Chapter III · The third currency",
    title: "Connection",
    paras: [
      "The only currency that compounds when given away. A hand held out is a deposit in two accounts at once.",
      "Follow-ups, birthdays, promises kept — the small entries that build a fortune of trust.",
    ],
    copySide: "copyRight",
  },
  {
    id: "growth",
    numeral: "IV",
    label: "Chapter IV · The fourth currency",
    title: "Growth",
    paras: [
      "Wealth is the slowest crop. It is not found — it is planted, rooted in the first three currencies and watered with patience.",
      "The best time to plant the tree was twenty years ago. The second best time is on this page.",
    ],
    copySide: "copyLeft",
  },
]





export default function StoryClient({ isSignedIn = false }: { isSignedIn?: boolean }) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const ctaHref = isSignedIn ? "/hub" : "/sign-up"

  useEffect(() => {
    const wrap = wrapRef.current
    if (!wrap) return
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    // ----- videos: play only while on screen -----
    const videos = Array.from(wrap.querySelectorAll<HTMLVideoElement>("video"))
    const vidIO = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          const v = e.target as HTMLVideoElement
          if (e.isIntersecting && !reduced) v.play().catch(() => {})
          else v.pause()
        }),
      { threshold: 0.2 }
    )
    videos.forEach((v) => vidIO.observe(v))

    // ----- finale reveals -----
    const reveals = Array.from(wrap.querySelectorAll<HTMLElement>(`.${sh.reveal}`))
    const revealIO = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (e.isIntersecting) (e.target as HTMLElement).classList.add(sh.in)
        }),
      { threshold: 0.25 }
    )
    reveals.forEach((el) => revealIO.observe(el))

    // ----- chapter nav active state -----
    const navLinks = Array.from(
      wrap.querySelectorAll<HTMLAnchorElement>("[data-nav]")
    )
    const chapterEls = Array.from(
      wrap.querySelectorAll<HTMLElement>("[data-chapter]")
    )
    const navIO = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (!e.isIntersecting) return
          const id = (e.target as HTMLElement).dataset.chapter
          navLinks.forEach((a) =>
            a.classList.toggle(s.active, a.dataset.nav === id)
          )
        }),
      { rootMargin: "-45% 0px -45% 0px" }
    )
    chapterEls.forEach((el) => navIO.observe(el))

    if (reduced) {
      return () => {
        vidIO.disconnect()
        revealIO.disconnect()
        navIO.disconnect()
      }
    }

    // ----- scroll-scrubbed timeline -----
    const progressBar = wrap.querySelector<HTMLElement>("[data-progress]")
    const heroWords = Array.from(
      wrap.querySelectorAll<HTMLElement>("[data-hero-word]")
    )
    const heroFade = Array.from(
      wrap.querySelectorAll<HTMLElement>("[data-hero-fade]")
    )
    const marquees = Array.from(
      wrap.querySelectorAll<HTMLElement>("[data-marquee]")
    )
    const ekgPath = wrap.querySelector<SVGPathElement>("[data-ekg]")
    const ekgLen = ekgPath?.getTotalLength() ?? 0
    if (ekgPath) {
      ekgPath.style.strokeDasharray = `${ekgLen}`
      ekgPath.style.strokeDashoffset = `${ekgLen}`
    }

    type Scene = {
      el: HTMLElement
      id: ChapterId
      plate: HTMLElement | null
      numeral: HTMLElement | null
      lines: HTMLElement[]
    }
    const scenes: Scene[] = chapterEls.map((el) => ({
      el,
      id: el.dataset.chapter as ChapterId,
      plate: el.querySelector<HTMLElement>("[data-plate]"),
      numeral: el.querySelector<HTMLElement>("[data-numeral]"),
      lines: Array.from(el.querySelectorAll<HTMLElement>("[data-line]")),
    }))

    const revealLines = (lines: HTMLElement[], p: number) => {
      lines.forEach((line, i) => {
        const t = easeOut(norm(p, 0.1 + i * 0.06, 0.34 + i * 0.06))
        line.style.opacity = `${t}`
        line.style.transform = `translateY(${(1 - t) * 42}px)`
      })
    }

    const update = () => {
      const vh = window.innerHeight
      const scrollY = window.scrollY
      const doc = document.documentElement

      if (progressBar) {
        const total = doc.scrollHeight - vh
        progressBar.style.width = `${(scrollY / Math.max(total, 1)) * 100}%`
      }

      // hero exit
      const hp = clamp(scrollY / (vh * 0.9), 0, 1)
      heroWords.forEach((w, i) => {
        const t = easeInOut(norm(hp, 0, 0.8))
        w.style.transform = `translateY(${-t * (60 + i * 45)}px)`
        w.style.opacity = `${1 - t}`
      })
      heroFade.forEach((el) => {
        el.style.opacity = `${1 - easeInOut(norm(hp, 0, 0.55))}`
      })

      // marquees scrub with scroll
      marquees.forEach((m) => {
        const dir = Number(m.dataset.dir || 1)
        const r = m.getBoundingClientRect()
        const t = (r.top + r.height) / (vh + r.height) // 1 → 0 across viewport
        const track = m.firstElementChild as HTMLElement | null
        if (track) track.style.transform = `translateX(${dir * (t - 0.5) * 30 - 25}%)`
      })

      // chapters
      scenes.forEach(({ el, id, plate, numeral, lines }) => {
        const rect = el.getBoundingClientRect()
        const scrollable = rect.height - vh
        // timeline opens well before the pin engages, so the incoming
        // chapter is already blooming as it slides up
        const lead = vh * 0.85
        const p = clamp((lead - rect.top) / Math.max(scrollable + lead, 1), 0, 1)
        if (rect.bottom < -vh || rect.top > vh * 2) return // offscreen, skip work

        if (numeral) {
          numeral.style.transform = `translateY(${(0.5 - p) * 22}vh)`
          numeral.style.opacity = `${easeOut(norm(p, 0, 0.15))}`
        }
        revealLines(lines, p)
        if (!plate) return

        const e = easeOut(norm(p, 0.02, 0.32))
        switch (id) {
          case "time": {
            // watch face opens like an iris, settling from a slight wind-up twist
            plate.style.clipPath = `circle(${8 + e * 66}% at 50% 50%)`
            plate.style.transform = `rotate(${(1 - e) * -8}deg) scale(${0.88 + e * 0.12})`
            plate.style.opacity = `${norm(p, 0, 0.08)}`
            break
          }
          case "vitality": {
            // swells into place like a beat; EKG draws with scroll
            plate.style.transform = `scale(${0.7 + e * 0.3})`
            plate.style.opacity = `${e}`
            if (ekgPath) {
              const d = easeInOut(norm(p, 0.06, 0.6))
              ekgPath.style.strokeDashoffset = `${ekgLen * (1 - d)}`
            }
            break
          }
          case "connection": {
            // reaches in from the left to meet the copy
            plate.style.transform = `translateX(${(1 - e) * -16}vw) scale(${0.92 + e * 0.08})`
            plate.style.opacity = `${e}`
            break
          }
          case "growth": {
            // reveals roots-first, canopy last — grown, not shown
            plate.style.clipPath = `inset(${(1 - e) * 72}% 0% 0% 0%)`
            plate.style.transform = `scale(${0.94 + e * 0.06})`
            plate.style.opacity = `${norm(p, 0, 0.06)}`
            break
          }
        }
      })
    }

    // Continuous rAF loop instead of scroll events: smooth/momentum
    // scrolling can move the page after the last scroll event fires,
    // which would freeze the timeline mid-transition. We only do real
    // work on frames where the scroll position actually changed.
    let rafId = 0
    let lastY = -1
    let lastH = -1
    let settleFrames = 0
    const loop = () => {
      const y = window.scrollY
      const h = window.innerHeight
      if (y !== lastY || h !== lastH) {
        lastY = y
        lastH = h
        settleFrames = 12 // keep updating briefly after movement stops
        update()
      } else if (settleFrames > 0) {
        settleFrames--
        update()
      }
      rafId = requestAnimationFrame(loop)
    }
    rafId = requestAnimationFrame(loop)

    return () => {
      cancelAnimationFrame(rafId)
      vidIO.disconnect()
      revealIO.disconnect()
      navIO.disconnect()
    }
  }, [])

  const chapterClass: Record<ChapterId, string> = {
    time: s.chTime,
    vitality: s.chVitality,
    connection: s.chConnection,
    growth: s.chGrowth,
  }

  return (
    <div ref={wrapRef} className={s.wrap}>
      <div className={s.progress} aria-hidden>
        <span data-progress />
      </div>
      <div className={s.grain} aria-hidden />

      <nav className={s.chapterNav} aria-label="Chapters">
        {CHAPTERS.map((c) => (
          <a key={c.id} href={`#${c.id}`} data-nav={c.id}>
            {c.numeral}
          </a>
        ))}
      </nav>

      {/* ================= HERO ================= */}
      <section className={s.hero}>
        <div>
          <p className={sh.kicker} data-hero-fade>
            Personal OS · An illustrated manifesto
          </p>
          <h1 className={s.heroTitle}>
            <span className={s.w} data-hero-word>The&nbsp;</span>
            <span className={s.w} data-hero-word>Four</span>
            <em data-hero-word>Currencies</em>
          </h1>
          <div className={sh.ruleOrnament} data-hero-fade>
            <i /><b>❧</b><i />
          </div>
          <p className={s.heroSub} data-hero-fade>
            Every life is an account. Four things are minted, traded and spent —
            this is their ledger, drawn in ink and set in motion.
          </p>
        </div>
        <div className={s.scrollCue} data-hero-fade>
          <span>Scroll to open the ledger</span>
          <em />
        </div>
      </section>

      {/* ================= MARQUEE ================= */}
      <div className={s.marquee} data-marquee data-dir="-1" aria-hidden>
        <div className={s.marqueeTrack}>
          {Array.from({ length: 4 }).map((_, i) => (
            <span key={i}>Tempus · Vita · Vinculum · Incrementum · </span>
          ))}
        </div>
      </div>

      {/* ================= CHAPTERS ================= */}
      {CHAPTERS.map((c) => (
        <section
          key={c.id}
          id={c.id}
          data-chapter={c.id}
          className={`${s.chapter} ${chapterClass[c.id]}`}
        >
          <div className={s.pin}>
            {c.id === "vitality" && (
              <svg
                className={s.ekg}
                viewBox="0 0 1200 200"
                preserveAspectRatio="none"
                aria-hidden
              >
                <path
                  data-ekg
                  d="M0,100 L180,100 L210,60 L240,140 L270,100 L420,100 L450,20 L480,180 L510,100 L700,100 L730,70 L760,130 L790,100 L950,100 L980,40 L1010,160 L1040,100 L1200,100"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                />
              </svg>
            )}
            <div className={s.numeral} data-numeral aria-hidden>
              {c.numeral}
            </div>
            <figure className={s.plate} data-plate>
              <video
                muted
                loop
                playsInline
                preload="metadata"
                poster={`/story/${c.id}.jpg`}
              >
                <source src={`/story/${c.id}.mp4`} type="video/mp4" />
              </video>
            </figure>
            <div className={`${s.copy} ${s[c.copySide]}`}>
              <p className={s.label} data-line>{c.label}</p>
              <h2 data-line>{c.title}</h2>
              {c.paras.map((t, i) => (
                <p key={i} data-line>{t}</p>
              ))}
            </div>
          </div>
        </section>
      ))}

      {/* ================= MARQUEE ================= */}
      <div className={s.marquee} data-marquee data-dir="1" aria-hidden>
        <div className={s.marqueeTrack}>
          {Array.from({ length: 4 }).map((_, i) => (
            <span key={i}>Spend well · Spend once · Spend together · Let it grow · </span>
          ))}
        </div>
      </div>

      {/* ================= FINALE ================= */}
      <section className={s.finale}>
        <p className={`${sh.kicker} ${sh.reveal}`}>The ledger, balanced</p>
        <h2 className={`${s.finaleTitle} ${sh.reveal}`}>Time well spent.</h2>
        <Link href={ctaHref} className={`${sh.cta} ${sh.reveal}`}>
          {isSignedIn ? "Go to your ledger" : "Open your ledger"} <ArrowRight size={16} />
        </Link>
        <div className={s.platesRow}>
          {CHAPTERS.map((c) => (
            <figure key={c.id} className={`${s.mini} ${sh.reveal}`}>
              <img src={`/story/${c.id}.jpg`} alt={`Engraving — ${c.title}`} />
              <figcaption>
                {c.numeral} · {c.title}
              </figcaption>
            </figure>
          ))}
        </div>
        <div className={`${sh.ruleOrnament} ${sh.reveal}`}>
          <i /><b>❧</b><i />
        </div>
      </section>

    </div>
  )
}
