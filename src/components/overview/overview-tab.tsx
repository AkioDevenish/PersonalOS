"use client"

import { useState, useEffect } from "react"
import { Card } from "../ui/card"
import { Music, ExternalLink, RefreshCw } from "lucide-react"

const MOODS = ["Calm", "Focused", "Tired", "Energized", "Anxious", "Grateful"]

const QUOTES = [
  { text: "Do not hurry; do not rest.", author: "Johann Wolfgang von Goethe" },
  { text: "The present moment is filled with joy and happiness.", author: "Thich Nhat Hanh" },
  { text: "Slow is smooth. Smooth is fast.", author: "Navy SEALs" },
]

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
  const pct = Math.min((value / max) * 100, 100)
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
  const [tasks, setTasks] = useState([
    { id: 1, text: "AirDrop Apple Health export", done: false },
    { id: 2, text: "Run weekly health analysis", done: false },
    { id: 3, text: "Read AI health report", done: false },
    { id: 4, text: "Pick one health action", done: false },
    { id: 5, text: "Commit code to GitHub", done: false },
    { id: 6, text: "Update project tracker", done: false },
  ])
  const [intention, setIntention] = useState("")
  const [notes, setNotes] = useState("")
  const [mood, setMood] = useState<string | null>(null)
  const [habits, setHabits] = useState([
    { name: "Deep Work", days: [true, true, false, true, false, false, false], color: "amber" as const },
    { name: "Movement", days: [true, false, true, true, false, true, false], color: "sage" as const },
    { name: "Reading", days: [false, true, true, false, true, false, false], color: "amber" as const },
  ])
  const [clock, setClock] = useState(new Date())
  const [loading, setLoading] = useState(true)

  // Music recommendation
  const [musicRec, setMusicRec] = useState<{ artist: string; track: string; genre: string; reason: string; previewUrl?: string; artworkUrl?: string; youtubeId?: string } | null>(null)
  const [musicLoading, setMusicLoading] = useState(true)

  // Live data
  const [healthData, setHealthData] = useState({ todaySteps: 0, avgSteps: 0 })
  const [dsData, setDsData] = useState({ activeProjects: 0, deployed: 0 })
  const [bizData, setBizData] = useState({ proposals: 0, clients: 0 })
  const [mktData, setMktData] = useState({ postsThisWeek: 0 })

  // Clock
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

  // Data fetch (do not block UI on slow music/Ollama)
  useEffect(() => {
    async function fetchAll() {
      try {
        const [health, ds, biz, mkt] = await Promise.all([
          fetch('/api/well-being/health-records?days=7').then(r => r.json()),
          fetch('/api/data-science/tracker').then(r => r.json()),
          fetch('/api/business/pipeline-summary').then(r => r.json()),
          fetch('/api/marketing/stats').then(r => r.json()),
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
        setBizData({
          proposals: biz.summary?.proposal || 0,
          clients: biz.summary?.client || 0,
        })
        setMktData({ postsThisWeek: mkt.this_week || 0 })

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

  const toggleTask = (id: number) => {
    setTasks(prev => prev.map(t => t.id === id ? { ...t, done: !t.done } : t))
  }

  const toggleHabit = (habitIdx: number, dayIdx: number) => {
    setHabits(prev => prev.map((h, i) => {
      if (i !== habitIdx) return h
      const d = [...h.days]
      d[dayIdx] = !d[dayIdx]
      return { ...h, days: d }
    }))
  }

  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  const completedTasks = tasks.filter(t => t.done).length
  const today = new Date()
  const dayName = mounted ? today.toLocaleDateString('en-US', { weekday: 'long' }) : ''
  const dateStr = mounted ? today.toLocaleDateString('en-US', { month: 'long', day: 'numeric' }) : ''
  const timeStr = mounted ? clock.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) : '--:--'
  const dateShort = mounted ? today.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }) : ''
  const quote = QUOTES[today.getDate() % QUOTES.length]

  const habitDays = ["M", "T", "W", "T", "F", "S", "S"]

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <header className="flex flex-col sm:flex-row items-start sm:items-end justify-between gap-2 pb-4 border-b border-[var(--border-subtle)]">
        <div>
          <h1
            className="text-[22px] italic text-[var(--deep-brown)]"
            style={{ fontFamily: "var(--font-display)" }}
          >
            Good {dayName}, <span className="not-italic text-[var(--amber)]">Akio</span>
          </h1>
          <p className="text-[13px] text-[var(--dust)] mt-1 font-light">
            {dateStr} &middot; A slow and steady day
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

      {/* Bento Grid */}
      <div className="grid gap-5 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 auto-rows-min">
        {/* Focus Card — spans 2 rows */}
        <Card className="lg:row-span-2 flex flex-col relative z-10">
          <CardLabel text="Today's Focus" />
          <textarea
            placeholder="What is your intention for today?"
            value={intention}
            onChange={e => setIntention(e.target.value)}
            className="w-full flex-1 min-h-[60px] bg-transparent text-[15px] italic text-[var(--deep-brown)] placeholder:text-[var(--dust)] resize-none focus:outline-none"
            style={{ fontFamily: "var(--font-display)" }}
          />
          <div className="border-t border-[var(--border-subtle)] pt-4 mt-2">
            <div className="flex items-center justify-between mb-2">
              <span className="text-[10px] uppercase tracking-[0.16em] text-[var(--dust)]">Tasks</span>
              <span className="text-[10px] text-[var(--dust)]">{completedTasks}/{tasks.length}</span>
            </div>
            <div className="space-y-2">
              {tasks.map(task => (
                <button
                  type="button"
                  key={task.id}
                  onClick={() => toggleTask(task.id)}
                  className="w-full flex items-center gap-3 py-2.5 text-left group touch-manipulation min-h-[44px]"
                >
                  <div
                    className="w-3.5 h-3.5 rounded-full border-[1.5px] flex-shrink-0 transition-colors"
                    style={{
                      borderColor: task.done ? "var(--amber)" : "var(--amber-low)",
                      backgroundColor: task.done ? "var(--amber)" : "transparent",
                    }}
                  />
                  <span
                    className={`text-[13px] font-light transition-colors ${
                      task.done ? "text-[var(--dust)] line-through" : "text-[var(--mid-brown)]"
                    }`}
                  >
                    {task.text}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </Card>

        {/* Deep Work Stat */}
        <Card>
          <CardLabel text="Deep Work" />
          <div
            className="text-[44px] font-light text-[var(--deep-brown)] leading-none"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {dsData.activeProjects}
          </div>
          <div className="text-[13px] text-[var(--mid-brown)] font-light mt-1">active projects</div>
          <div className="mt-4">
            <StatBar value={dsData.activeProjects} max={10} color="amber" />
          </div>
        </Card>

        {/* Mood Check */}
        <Card variant="soft" className="relative z-10">
          <CardLabel text="Mood Check" />
          <div className="flex flex-wrap gap-2 mt-1">
            {MOODS.map(m => (
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

        {/* Music Recommendation */}
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
              {musicRec.youtubeId ? (
                <div className="mt-4 flex-1 min-h-[140px]">
                  <iframe
                    className="w-full h-full rounded-[8px]"
                    src={`https://www.youtube.com/embed/${musicRec.youtubeId}?autoplay=0`}
                    title="YouTube video player"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                  />
                </div>
              ) : musicRec.previewUrl ? (
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
              ) : (
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
              )}
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <div className="text-[13px] text-[var(--dust)]">No recommendation</div>
            </div>
          )}
        </Card>

        {/* Reading / Health Stat */}
        <Card>
          <CardLabel text="Movement" />
          <div
            className="text-[44px] font-light text-[var(--deep-brown)] leading-none"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {loading ? "—" : healthData.todaySteps.toLocaleString()}
          </div>
          <div className="text-[13px] text-[var(--mid-brown)] font-light mt-1">steps today</div>
          <div className="mt-4">
            <StatBar value={healthData.todaySteps} max={12000} color="sage" />
          </div>
        </Card>

        {/* Habit Tracker — spans 2 columns */}
        <Card className="md:col-span-2 relative z-10">
          <CardLabel text="Habit Tracker" />
          <div className="space-y-3 mt-1">
            {habits.map((habit, hi) => (
              <div key={hi} className="flex items-center gap-4">
                <span className="w-20 text-[12px] font-light text-[var(--mid-brown)]">{habit.name}</span>
                <div className="flex gap-2 flex-1">
                  {habit.days.map((done, di) => (
                    <button
                      type="button"
                      key={di}
                      onClick={() => toggleHabit(hi, di)}
                      className="w-11 h-11 min-w-[44px] min-h-[44px] rounded-[6px] transition-colors touch-manipulation flex items-center justify-center p-0"
                      style={{
                        backgroundColor: done
                          ? (habit.color === "amber" ? "var(--amber)" : "var(--sage)")
                          : "transparent",
                        border: `1px solid ${done
                          ? (habit.color === "amber" ? "var(--amber)" : "var(--sage)")
                          : "var(--border-mid)"}`,
                      }}
                      title={habitDays[di]}
                    />
                  ))}
                </div>
                <span className="text-[11px] text-[var(--dust)] w-8 text-right">
                  {habit.days.filter(Boolean).length}/7
                </span>
              </div>
            ))}
          </div>
          <div className="flex gap-6 mt-3 pt-3 border-t border-[var(--border-subtle)] ml-24">
            {habitDays.map((d, i) => (
              <span key={i} className="flex-1 text-center text-[10px] text-[var(--dust)]">{d}</span>
            ))}
          </div>
        </Card>

        {/* Quote / Reflection */}
        <Card variant="soft" className="flex flex-col justify-center">
          <CardLabel text="Reflection" />
          <p
            className="text-[18px] italic text-[var(--deep-brown)] leading-relaxed mt-2"
            style={{ fontFamily: "var(--font-display)" }}
          >
            &ldquo;{quote.text}&rdquo;
          </p>
          <p className="text-[11px] text-[var(--dust)] mt-3 font-light">— {quote.author}</p>
        </Card>
      </div>
    </div>
  )
}
