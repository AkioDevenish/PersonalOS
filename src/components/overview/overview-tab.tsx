"use client"

import { useState, useEffect } from "react"
import { Card } from "../ui/card"
import { Music, ExternalLink, RefreshCw } from "lucide-react"
import { useUser } from '@clerk/nextjs'

function CardLabel({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-2 mb-3">
      <div className="w-[18px] h-[1px] bg-[var(--amber)]" />
      <span className="text-[10px] font-medium uppercase tracking-[0.16em] text-[var(--dust)]">
        {text}
      </span>
    </div>
  )
}

function StatBar({ value, max, color }: { value: number; max: number; color: "amber" | "sage" }) {
  const pct = max > 0 ? Math.min((value / max) * 100, 100) : 0
  const trackColor = color === "amber" ? "var(--amber-low)" : "var(--sage-low)"
  const fillColor = color === "amber" ? "var(--amber)" : "var(--sage)"
  return (
    <div className="w-full h-1 rounded-sm" style={{ backgroundColor: trackColor }}>
      <div
        className="h-full rounded-sm origin-left"
        style={{
          backgroundColor: fillColor,
          width: `${pct}%`,
          transform: "scaleX(1)",
          transition: "width 1.4s cubic-bezier(0.22,1,0.36,1)",
        }}
      />
    </div>
  )
}

export function OverviewTab() {
  const { user } = useUser()
  const [tasks, setTasks] = useState<{ id: number; text: string; done: boolean }[]>([])
  const [intention, setIntention] = useState("")
  const [mood, setMood] = useState<string | null>(null)
  const [habits, setHabits] = useState<{ name: string; days: boolean[]; color: "amber" | "sage" }[]>([])
  const [clock, setClock] = useState(new Date())
  const [loading, setLoading] = useState(true)

  const [musicRec, setMusicRec] = useState<{ artist: string; track: string; genre: string; reason: string; previewUrl?: string; artworkUrl?: string; youtubeId?: string } | null>(null)
  const [musicLoading, setMusicLoading] = useState(true)

  const [healthData, setHealthData] = useState({ todaySteps: 0, avgSteps: 0 })
  const [dsData, setDsData] = useState({ activeProjects: 0, deployed: 0 })

  useEffect(() => {
    const timer = setInterval(() => setClock(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  const loadMusic = async (moodValue: string | null, steps: number) => {
    setMusicLoading(true)
    try {
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 25_000)
      const now = new Date()
      const res = await fetch('/api/overview/music-recommendation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          mood: moodValue,
          steps,
          timeOfDay: now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true }),
          dayName: now.toLocaleDateString('en-US', { weekday: 'long' }),
        }),
      })
      clearTimeout(timeout)
      const data = await res.json()
      if (data.track) setMusicRec(data)
    } catch (e) {
      console.error(e)
    } finally {
      setMusicLoading(false)
    }
  }

  useEffect(() => {
    async function fetchAll() {
      try {
        const [health, ds] = await Promise.all([
          fetch('/api/well-being/health-records?days=7').then(r => r.json()),
          fetch('/api/data-science/tracker').then(r => r.json()),
        ])
        const records = health.records || []
        const todaySteps = records.length
          ? Math.max(...records.map((r: { steps?: number }) => r.steps || 0))
          : 0
        setHealthData({
          todaySteps,
          avgSteps: records.length
            ? Math.round(records.reduce((s: number, r: { steps?: number }) => s + (r.steps || 0), 0) / records.length)
            : 0,
        })
        setDsData({
          activeProjects: ds.projects?.filter((p: { status?: string }) => p.status === 'In Progress').length || 0,
          deployed: ds.projects?.filter((p: { deployed_url?: string }) => p.deployed_url && p.deployed_url !== '').length || 0,
        })

        void loadMusic(null, todaySteps)
      } catch (e) {
        console.error(e)
        setMusicLoading(false)
      } finally {
        setLoading(false)
      }
    }
    fetchAll()
  }, [])

  const refreshMusic = () => loadMusic(mood, healthData.todaySteps)

  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  const today = new Date()
  const dayName = mounted ? today.toLocaleDateString('en-US', { weekday: 'long' }) : ''
  const dateStr = mounted ? today.toLocaleDateString('en-US', { month: 'long', day: 'numeric' }) : ''
  const timeStr = mounted ? clock.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) : '--:--'
  const dateShort = mounted ? today.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) : ''

  return (
    <div className="space-y-6 animate-fade-in">
      <header className="flex flex-col sm:flex-row items-start sm:items-end justify-between gap-2 pb-4 border-b border-[var(--border-subtle)]">
        <div>
          <h1
            className="text-[22px] italic text-[var(--deep-brown)]"
            style={{ fontFamily: "var(--font-display)" }}
          >
            Good {dayName}, <span className="not-italic text-[var(--amber)]">{user?.firstName || 'there'}</span>
          </h1>
          <p className="text-[13px] text-[var(--dust)] mt-1 font-light">
            {dateStr}
          </p>
        </div>
        <div className="text-right">
          <div
            className="text-[28px] sm:text-[42px] font-light leading-none text-[var(--deep-brown)]"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {timeStr}
          </div>
          <div className="text-[10px] uppercase tracking-[0.14em] text-[var(--dust)] mt-1">
            {dateShort}
          </div>
        </div>
      </header>

      <div className="grid gap-5 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 auto-rows-min">
        <Card className="lg:row-span-2 flex flex-col relative z-10">
          <CardLabel text="Today's Focus" />
          <textarea
            placeholder="What is your intention for today?"
            value={intention}
            onChange={e => setIntention(e.target.value)}
            className="w-full flex-1 min-h-[60px] bg-transparent text-[15px] italic text-[var(--deep-brown)] placeholder:text-[var(--dust)] resize-none focus:outline-none"
            style={{ fontFamily: "var(--font-display)" }}
          />
        </Card>

        <Card>
          <CardLabel text="Deep Work" />
          <div
            className="text-[44px] font-light text-[var(--deep-brown)] leading-none"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {dsData.activeProjects}
          </div>
          <div className="text-[13px] text-[var(--mid-brown)] font-light mt-1">active projects</div>
        </Card>

        <Card variant="soft" className="relative z-10">
          <CardLabel text="Mood Check" />
          <div className="flex flex-wrap gap-2 mt-1">
            {["Calm", "Focused", "Tired", "Energized", "Anxious", "Grateful"].map(m => (
              <button
                type="button"
                key={m}
                onClick={() => {
                  const next = m === mood ? null : m
                  setMood(next)
                  void loadMusic(next, healthData.todaySteps)
                }}
                className="px-4 py-2.5 rounded-full text-[12px] font-light transition-all duration-200 touch-manipulation min-h-[44px]"
                style={{
                  backgroundColor: m === mood ? "var(--amber)" : "transparent",
                  color: m === mood ? "#FAF6EF" : "var(--mid-brown)",
                  border: `1px solid ${m === mood ? "var(--amber)" : "var(--border-mid)"}`,
                }}
              >
                {m}
              </button>
            ))}
          </div>
        </Card>

        <Card className="flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <CardLabel text="Now Playing" />
            <button
              type="button"
              onClick={refreshMusic}
              disabled={musicLoading}
              className="p-2.5 rounded-md hover:bg-[var(--soft-warm)] transition-colors disabled:opacity-50 touch-manipulation min-h-[44px] min-w-[44px] flex items-center justify-center"
              title="Get new recommendation"
            >
              <RefreshCw className={`w-3.5 h-3.5 text-[var(--dust)] ${musicLoading ? 'animate-spin' : ''}`} />
            </button>
          </div>
          {musicLoading ? (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-[13px] text-[var(--dust)]">Curating...</div>
            </div>
          ) : musicRec ? (
            <div className="flex flex-col flex-1">
              <div className="flex items-start gap-3">
                {musicRec.artworkUrl ? (
                  <img src={musicRec.artworkUrl} alt={`${musicRec.track} cover`} className="w-10 h-10 rounded-[8px] object-cover flex-shrink-0" />
                ) : (
                  <div className="w-10 h-10 rounded-[8px] bg-[var(--soft-warm)] flex items-center justify-center flex-shrink-0">
                    <Music className="w-5 h-5 text-[var(--deep-brown)]" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div
                    className="text-[15px] font-light text-[var(--deep-brown)] truncate"
                    style={{ fontFamily: "var(--font-display)" }}
                  >
                    {musicRec.track}
                  </div>
                  <div className="text-[12px] text-[var(--mid-brown)] truncate">{musicRec.artist}</div>
                  <span className="inline-block mt-1 px-2 py-0.5 rounded-full text-[10px] bg-[var(--soft-warm)] text-[var(--deep-brown)]">
                    {musicRec.genre}
                  </span>
                </div>
              </div>
              <p className="text-[11px] text-[var(--dust)] mt-2 leading-relaxed">{musicRec.reason}</p>
              {musicRec.previewUrl ? (
                <>
                  <audio controls src={musicRec.previewUrl} className="w-full h-[32px] mt-3 bg-transparent rounded-md" />
                  <a
                    href={`https://open.spotify.com/search/${encodeURIComponent(musicRec.artist + ' ' + musicRec.track)}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-auto pt-3 flex items-center justify-center gap-2 px-3 py-2 bg-[var(--deep-brown)] text-[var(--warm-white)] rounded-[8px] text-[12px] hover:opacity-90 transition-opacity"
                  >
                    <Music className="w-3.5 h-3.5" />
                    Listen on Spotify
                    <ExternalLink className="w-3 h-3 opacity-60" />
                  </a>
                </>
              ) : null}
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-[13px] text-[var(--dust)]">No recommendation</div>
            </div>
          )}
        </Card>

        <Card>
          <CardLabel text="Movement" />
          <div
            className="text-[44px] font-light text-[var(--deep-brown)] leading-none"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {loading ? "—" : healthData.todaySteps.toLocaleString()}
          </div>
          <div className="text-[13px] text-[var(--mid-brown)] font-light mt-1">steps today</div>
        </Card>
      </div>
    </div>
  )
}
