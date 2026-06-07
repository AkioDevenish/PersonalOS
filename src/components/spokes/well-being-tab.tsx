"use client"

import { useEffect, useRef, useState } from "react"
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ComposedChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { Card } from "../ui/card"
import { KPIMetric } from "../ui/kpi-metric"
import { ChevronDown, ChevronLeft, ChevronRight, RefreshCw, Sparkles, Stethoscope, UtensilsCrossed, Loader2, Brain, Sun, Moon, Sunrise, Sunset, Cookie, Clock, History, ChefHat, Flame, Leaf, Zap, Database, Apple, Dumbbell, Footprints, Ear, Activity, Compass, Battery, Trash2, Mic, MicOff, Send } from "lucide-react"

interface HealthRecord {
  date: string
  steps: number | null
  distance_km: number | null
  flights_climbed: number | null
  walking_speed: number | null
  walking_steadiness: number | null
  walking_asymmetry_pct?: number | null
  walking_step_length?: number | null
  walking_double_support_pct?: number | null
  stair_ascent_speed?: number | null
  active_energy_burned?: number | null
  basal_energy_burned?: number | null
  headphone_audio_exposure?: number | null
  mindful_session_mins?: number | null
  time_in_daylight?: number | null
  total_sleep_hours?: number | null
  avg_blood_glucose_mgdl?: number | null
  dietary_carbohydrates_g?: number | null
  insulin_delivery_iu?: number | null
  source_file?: string
}

interface AIReport {
  id: number
  period: string
  report_text: string
  created_at: string
}



interface StateOfMindEntry {
  id: string
  timestamp: string
  labels: string
  valence: number | null
}

interface TrendPoint {
  date: string
  label: string
  steps: number | null
  distance_km: number | null
  flights_climbed: number | null
  walking_speed: number | null
  walking_steadiness?: number | null
  walking_asymmetry_pct?: number | null
  walking_step_length?: number | null
  walking_double_support_pct?: number | null
  stair_ascent_speed?: number | null
  active_energy_burned?: number | null
  basal_energy_burned?: number | null
  headphone_audio_exposure?: number | null
  mindful_session_mins?: number | null
  time_in_daylight?: number | null
  total_sleep_hours?: number | null
  avg_blood_glucose_mgdl?: number | null
  dietary_carbohydrates_g?: number | null
  insulin_delivery_iu?: number | null
}

const availableMetrics = [
  // Physical Activity
  { id: 'steps', label: 'Steps', unit: 'steps', color: 'var(--sage)' },
  { id: 'distance_km', label: 'Distance', unit: 'km', color: 'var(--sage)' },
  { id: 'flights_climbed', label: 'Flights', unit: 'floors', color: 'var(--sage)' },
  { id: 'active_energy_burned', label: 'Active Cals', unit: 'kcal', color: 'var(--amber)' },
  { id: 'basal_energy_burned', label: 'Basal Cals', unit: 'kcal', color: 'var(--amber)' },
  { id: 'time_in_daylight', label: 'Daylight', unit: 'min', color: '#D4A843' },
  // Mobility & Gait
  { id: 'walking_speed', label: 'Walk Speed', unit: 'km/h', color: '#7A8F6E' },
  { id: 'walking_steadiness', label: 'Steadiness', unit: '%', color: '#7A8F6E' },
  { id: 'walking_asymmetry_pct', label: 'Asymmetry', unit: '%', color: '#B07850' },
  { id: 'walking_step_length', label: 'Step Length', unit: 'm', color: '#7A8F6E' },
  { id: 'walking_double_support_pct', label: 'Dbl Support', unit: '%', color: '#B07850' },
  { id: 'stair_ascent_speed', label: 'Stair Speed', unit: 'm/s', color: '#7A8F6E' },
  // Recovery & Environment
  { id: 'total_sleep_hours', label: 'Total Sleep', unit: 'hrs', color: '#9b8b7e' },
  { id: 'mindful_session_mins', label: 'Mindfulness', unit: 'min', color: '#9b8b7e' },
  { id: 'headphone_audio_exposure', label: 'Audio Exp.', unit: 'dB', color: '#9b8b7e' },
  // Metabolic
  { id: 'avg_blood_glucose_mgdl', label: 'Glucose', unit: 'mg/dL', color: '#C75B5B' },
  { id: 'dietary_carbohydrates_g', label: 'Carbs', unit: 'g', color: '#C75B5B' },
  { id: 'insulin_delivery_iu', label: 'Insulin', unit: 'IU', color: '#C75B5B' },
] as const;

const reportPeriods = [
  { value: "hourly", label: "Hourly" },
  { value: "daily", label: "Daily" },
  { value: "weekly", label: "Weekly" },
  { value: "monthly", label: "Monthly" },
]

const chartTypes = [
  { value: "bar", label: "Bar" },
  { value: "line", label: "Line" },
  { value: "area", label: "Area" },
] as const

type ChartType = (typeof chartTypes)[number]["value"]

const rangeOptions = [
  { days: 1, label: "Daily" },
  { days: 7, label: "Last 7 days" },
  { days: 30, label: "Last 30 days" },
  { days: 90, label: "Last 90 days" },
]

const reportTitles: Record<string, string> = {
  hourly: "Hourly report",
  daily: "Daily Report",
  weekly: "Weekly Report",
  monthly: "Monthly Report",
}

function cleanReportText(text: string) {
  const withoutAnsi = text
    .replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/[–—]/g, "-")
    .replace(/\*\s+([^*\n]+?)\s+\*/g, "*$1*")
  const lines = withoutAnsi.split("\n")

  return lines
    .map((line, index) => {
      const nextLine = lines[index + 1]?.trimStart()
      const lastWord = line.match(/([A-Za-z]{2,})$/)?.[1]
      const nextWord = nextLine?.match(/^([A-Za-z]{2,})/)?.[1]

      if (lastWord && nextWord && nextWord.toLowerCase().startsWith(lastWord.toLowerCase())) {
        return line.slice(0, -lastWord.length).trimEnd()
      }

      return line
    })
    .join("\n")
}

function renderInlineMarkdown(text: string) {
  return text.split(/(\*\*[^*]+\*\*|\*[^*\n]+\*)/g).map((part, index) => {
    if (part.startsWith("**") && part.endsWith("**")) {
      return <strong key={index} className="font-medium text-[var(--deep-brown)]">{part.slice(2, -2)}</strong>
    }

    if (part.startsWith("*") && part.endsWith("*")) {
      return <em key={index}>{part.slice(1, -1)}</em>
    }

    return <span key={index}>{part}</span>
  })
}

const MODEL_TAGS: Record<string, string[]> = {
  data_scientist: ['[BEHAVIORAL DRIFT]', '[CORRELATION HYPOTHESIS]', '[SENSOR OUTLIER]', '[ENVIRONMENTAL LOAD]'],
  endocrinologist: ['[METABOLIC SPIKE]'],
  nutritionist: ['[NUTRITIONAL IMPACT]'],
  strength_coach: ['[INJURY PREDICTOR]', '[RECOVERY DEFICIT]', '[OPTIMIZATION LEVER]']
}

function ReportMarkdown({ text, activeModel }: { text: string, activeModel: string | null }) {
  const lines = cleanReportText(text).split("\n").map(l => l.trim()).filter(Boolean)

  if (lines.length === 0) {
    return <div className="p-4 text-[var(--dust)] text-[12px]">No data found in report.</div>
  }

  let currentTag: string | null = null;
  const activeTags = activeModel && activeModel !== 'general' ? (MODEL_TAGS[activeModel] || []) : null;

  return (
    <div className="flex flex-col gap-3">
      <div className="font-mono text-[12px] leading-relaxed bg-[var(--linen)] text-[var(--mid-brown)] p-4 rounded-[8px] overflow-x-auto border border-[var(--border-subtle)] w-full min-h-[140px]">
        {lines.map((line, i) => {
          const tagMatch = line.match(/^(\[[A-Z\s]+\]|[A-Z][A-Z\s]{3,})$/)
          if (tagMatch) {
            currentTag = tagMatch[1]
          } else if (!currentTag) {
            currentTag = 'GENERAL'
          }

          let tagColor = "text-[var(--mid-brown)]"
          if (line.includes("[ANOMALY DETECTED]") || line.includes("[RECOVERY DEFICIT]") || line.includes("[INJURY PREDICTOR]")) tagColor = "text-[var(--accent-danger)] font-medium"
          else if (line.includes("[CORRELATION HYPOTHESIS]") || line.includes("[METABOLIC SPIKE]") || line.includes("[ENVIRONMENTAL LOAD]") || line.includes("[NUTRITIONAL IMPACT]")) tagColor = "text-[var(--amber)] font-medium"
          else if (line.includes("[OPTIMIZATION LEVER]") || line.includes("[POSITIVE SIGNAL]")) tagColor = "text-[var(--sage)] font-medium"
          else if (line.includes("[BEHAVIORAL DRIFT]")) tagColor = "text-[var(--deep-brown)] font-medium"
          else if (line.includes("[SENSOR OUTLIER]")) tagColor = "text-[var(--dust)] font-medium"
          
          let opacityClass = "opacity-100"
          if (activeTags && currentTag && !activeTags.includes(currentTag)) {
            opacityClass = "opacity-30 grayscale transition-opacity duration-300"
          }

          const match = line.match(/^(\[[A-Z\s]+\]):?\s*(.*)$/)
          if (match) {
            const segments = match[2].split('**')
            return (
              <div key={i} className={`mb-2 last:mb-0 flex gap-2 ${opacityClass}`}>
                <span className={`shrink-0 ${tagColor}`}>{match[1]}</span>
                <span className="text-[var(--deep-brown)] whitespace-pre-wrap">
                  {segments.map((segment, index) => 
                    index % 2 === 1 ? <strong key={index} className="font-semibold text-[var(--deep-brown)]">{segment}</strong> : segment
                  )}
                </span>
              </div>
            )
          }
          return (
            <div key={i} className={`mb-2 last:mb-0 text-[var(--mid-brown)] ${opacityClass}`}>
              {renderInlineMarkdown(line)}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function parseRecordDate(dateStr: string): Date {
  // Safari requires the "T" separator for ISO 8601 parsing
  return new Date(dateStr.replace(" ", "T"))
}

function getRecordLabel(record: HealthRecord) {
  return parseRecordDate(record.date).toLocaleDateString(undefined, { month: "short", day: "numeric" })
}

function toDateKey(date: Date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, "0")
  const day = String(date.getDate()).padStart(2, "0")
  return `${year}-${month}-${day}`
}

function toTrendPoint(record: HealthRecord): TrendPoint {
  return {
    date: record.date,
    label: getRecordLabel(record),
    steps: record.steps,
    distance_km: record.distance_km,
    flights_climbed: record.flights_climbed,
    walking_speed: record.walking_speed,
    walking_steadiness: record.walking_steadiness,
    walking_asymmetry_pct: record.walking_asymmetry_pct,
    walking_step_length: record.walking_step_length,
    walking_double_support_pct: record.walking_double_support_pct,
    stair_ascent_speed: record.stair_ascent_speed,
    active_energy_burned: record.active_energy_burned,
    basal_energy_burned: record.basal_energy_burned,
    headphone_audio_exposure: record.headphone_audio_exposure,
    mindful_session_mins: record.mindful_session_mins,
    time_in_daylight: record.time_in_daylight,
    total_sleep_hours: record.total_sleep_hours,
    avg_blood_glucose_mgdl: record.avg_blood_glucose_mgdl,
    dietary_carbohydrates_g: record.dietary_carbohydrates_g,
    insulin_delivery_iu: record.insulin_delivery_iu,
  }
}

function toHourLabel(hour: number) {
  const hour12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
  const ampm = hour < 12 ? "AM" : "PM"
  return `${hour12}${ampm}`
}

function deltaValue(current: number | null, previous: number | null) {
  if (current === null) return null
  if (previous === null) return current
  return Math.max(current - previous, 0)
}

function buildTrendSeries(records: HealthRecord[], days: number): TrendPoint[] {
  const sortedRecords = [...records].sort((a, b) => parseRecordDate(a.date).getTime() - parseRecordDate(b.date).getTime())
  const latestRecord = sortedRecords.at(-1)

  if (days === 1) {
    if (!latestRecord) return []

    const activeDateKey = toDateKey(parseRecordDate(latestRecord.date))
    const recordsForDay = sortedRecords.filter((record) => toDateKey(parseRecordDate(record.date)) === activeDateKey)
    const latestByHour = new Map<number, Partial<HealthRecord>>()
    recordsForDay.forEach((record) => {
      const hour = parseRecordDate(record.date).getHours()
      const existing = latestByHour.get(hour) || { date: record.date }
      
      latestByHour.set(hour, {
        ...existing,
        steps: record.steps ?? existing.steps,
        distance_km: record.distance_km ?? existing.distance_km,
        flights_climbed: record.flights_climbed ?? existing.flights_climbed,
        walking_speed: record.walking_speed ?? existing.walking_speed,
        walking_steadiness: record.walking_steadiness ?? existing.walking_steadiness,
        walking_asymmetry_pct: record.walking_asymmetry_pct ?? existing.walking_asymmetry_pct,
        walking_step_length: record.walking_step_length ?? existing.walking_step_length,
        walking_double_support_pct: record.walking_double_support_pct ?? existing.walking_double_support_pct,
        stair_ascent_speed: record.stair_ascent_speed ?? existing.stair_ascent_speed,
        active_energy_burned: record.active_energy_burned ?? existing.active_energy_burned,
        basal_energy_burned: record.basal_energy_burned ?? existing.basal_energy_burned,
        headphone_audio_exposure: record.headphone_audio_exposure ?? existing.headphone_audio_exposure,
        mindful_session_mins: record.mindful_session_mins ?? existing.mindful_session_mins,
        time_in_daylight: record.time_in_daylight ?? existing.time_in_daylight,
        total_sleep_hours: record.total_sleep_hours ?? existing.total_sleep_hours,
        avg_blood_glucose_mgdl: record.avg_blood_glucose_mgdl ?? existing.avg_blood_glucose_mgdl,
        dietary_carbohydrates_g: record.dietary_carbohydrates_g ?? existing.dietary_carbohydrates_g,
        insulin_delivery_iu: record.insulin_delivery_iu ?? existing.insulin_delivery_iu,
        date: record.date,
      })
    })

    let previousSnapshot: Partial<HealthRecord> = {}
    const slots: TrendPoint[] = []

    for (let hour = 0; hour < 24; hour++) {
      const record = latestByHour.get(hour)
      const slotDate = parseRecordDate(latestRecord.date)
      slotDate.setHours(hour, 0, 0, 0)

      if (!record) {
        slots.push({
          date: slotDate.toISOString(),
          label: toHourLabel(hour),
          steps: 0, distance_km: 0, flights_climbed: 0, walking_speed: null,
          walking_steadiness: null, walking_asymmetry_pct: null, walking_step_length: null,
          walking_double_support_pct: null, stair_ascent_speed: null,
          active_energy_burned: 0, basal_energy_burned: null,
          headphone_audio_exposure: null, mindful_session_mins: 0, time_in_daylight: null,
          total_sleep_hours: null, avg_blood_glucose_mgdl: null,
          dietary_carbohydrates_g: null, insulin_delivery_iu: null,
        })
        continue
      }

      const currentSteps = record.steps ?? previousSnapshot.steps ?? null
      const currentDistance = record.distance_km ?? previousSnapshot.distance_km ?? null
      const currentFlights = record.flights_climbed ?? previousSnapshot.flights_climbed ?? null
      const currentActive = record.active_energy_burned ?? previousSnapshot.active_energy_burned ?? null
      const currentMindful = record.mindful_session_mins ?? previousSnapshot.mindful_session_mins ?? null

      const steps = deltaValue(currentSteps, previousSnapshot.steps ?? null)
      const distance_km = deltaValue(currentDistance, previousSnapshot.distance_km ?? null)
      const flights_climbed = deltaValue(currentFlights, previousSnapshot.flights_climbed ?? null)
      const active_energy_burned = deltaValue(currentActive, previousSnapshot.active_energy_burned ?? null)
      const mindful_session_mins = deltaValue(currentMindful, previousSnapshot.mindful_session_mins ?? null)

      slots.push({
        date: record.date ?? slotDate.toISOString(),
        label: toHourLabel(hour),
        steps, distance_km, flights_climbed,
        walking_speed: record.walking_speed ?? previousSnapshot.walking_speed ?? null,
        walking_steadiness: record.walking_steadiness ?? previousSnapshot.walking_steadiness ?? null,
        walking_asymmetry_pct: record.walking_asymmetry_pct ?? previousSnapshot.walking_asymmetry_pct ?? null,
        walking_step_length: record.walking_step_length ?? previousSnapshot.walking_step_length ?? null,
        walking_double_support_pct: record.walking_double_support_pct ?? previousSnapshot.walking_double_support_pct ?? null,
        stair_ascent_speed: record.stair_ascent_speed ?? previousSnapshot.stair_ascent_speed ?? null,
        active_energy_burned, basal_energy_burned: record.basal_energy_burned ?? previousSnapshot.basal_energy_burned ?? null,
        headphone_audio_exposure: record.headphone_audio_exposure ?? previousSnapshot.headphone_audio_exposure ?? null,
        mindful_session_mins, time_in_daylight: record.time_in_daylight ?? previousSnapshot.time_in_daylight ?? null,
        total_sleep_hours: record.total_sleep_hours ?? previousSnapshot.total_sleep_hours ?? null,
        avg_blood_glucose_mgdl: record.avg_blood_glucose_mgdl ?? previousSnapshot.avg_blood_glucose_mgdl ?? null,
        dietary_carbohydrates_g: record.dietary_carbohydrates_g ?? previousSnapshot.dietary_carbohydrates_g ?? null,
        insulin_delivery_iu: record.insulin_delivery_iu ?? previousSnapshot.insulin_delivery_iu ?? null,
      })
      
      previousSnapshot.steps = currentSteps ?? undefined
      previousSnapshot.distance_km = currentDistance ?? undefined
      previousSnapshot.flights_climbed = currentFlights ?? undefined
      previousSnapshot.active_energy_burned = currentActive ?? undefined
      previousSnapshot.mindful_session_mins = currentMindful ?? undefined
      if (record.walking_speed != null) previousSnapshot.walking_speed = record.walking_speed
      if (record.walking_steadiness != null) previousSnapshot.walking_steadiness = record.walking_steadiness
      if (record.walking_asymmetry_pct != null) previousSnapshot.walking_asymmetry_pct = record.walking_asymmetry_pct
      if (record.walking_step_length != null) previousSnapshot.walking_step_length = record.walking_step_length
      if (record.walking_double_support_pct != null) previousSnapshot.walking_double_support_pct = record.walking_double_support_pct
      if (record.stair_ascent_speed != null) previousSnapshot.stair_ascent_speed = record.stair_ascent_speed
      if (record.basal_energy_burned != null) previousSnapshot.basal_energy_burned = record.basal_energy_burned
      if (record.total_sleep_hours != null) previousSnapshot.total_sleep_hours = record.total_sleep_hours
      if (record.time_in_daylight != null) previousSnapshot.time_in_daylight = record.time_in_daylight
      if (record.headphone_audio_exposure != null) previousSnapshot.headphone_audio_exposure = record.headphone_audio_exposure
      if (record.avg_blood_glucose_mgdl != null) previousSnapshot.avg_blood_glucose_mgdl = record.avg_blood_glucose_mgdl
      if (record.dietary_carbohydrates_g != null) previousSnapshot.dietary_carbohydrates_g = record.dietary_carbohydrates_g
      if (record.insulin_delivery_iu != null) previousSnapshot.insulin_delivery_iu = record.insulin_delivery_iu
    }
    return slots
  }

  const latestByDay = new Map<string, Partial<HealthRecord>>()
  sortedRecords.forEach((record) => {
    const key = toDateKey(parseRecordDate(record.date))
    const existing = latestByDay.get(key) || { date: record.date }
    
    latestByDay.set(key, {
      ...existing,
      steps: record.steps ?? existing.steps,
      distance_km: record.distance_km ?? existing.distance_km,
      flights_climbed: record.flights_climbed ?? existing.flights_climbed,
      walking_speed: record.walking_speed ?? existing.walking_speed,
      walking_steadiness: record.walking_steadiness ?? existing.walking_steadiness,
      walking_asymmetry_pct: record.walking_asymmetry_pct ?? existing.walking_asymmetry_pct,
      walking_step_length: record.walking_step_length ?? existing.walking_step_length,
      walking_double_support_pct: record.walking_double_support_pct ?? existing.walking_double_support_pct,
      stair_ascent_speed: record.stair_ascent_speed ?? existing.stair_ascent_speed,
      active_energy_burned: record.active_energy_burned ?? existing.active_energy_burned,
      basal_energy_burned: record.basal_energy_burned ?? existing.basal_energy_burned,
      headphone_audio_exposure: record.headphone_audio_exposure ?? existing.headphone_audio_exposure,
      mindful_session_mins: record.mindful_session_mins ?? existing.mindful_session_mins,
      time_in_daylight: record.time_in_daylight ?? existing.time_in_daylight,
      total_sleep_hours: record.total_sleep_hours ?? existing.total_sleep_hours,
      avg_blood_glucose_mgdl: record.avg_blood_glucose_mgdl ?? existing.avg_blood_glucose_mgdl,
      dietary_carbohydrates_g: record.dietary_carbohydrates_g ?? existing.dietary_carbohydrates_g,
      insulin_delivery_iu: record.insulin_delivery_iu ?? existing.insulin_delivery_iu,
      date: record.date,
    })
  })

  const end = new Date()
  end.setHours(0, 0, 0, 0)
  const start = new Date(end)
  start.setDate(end.getDate() - days + 1)

  return Array.from({ length: days }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)
    const record = latestByDay.get(toDateKey(date))

    if (record) {
      return toTrendPoint(record as HealthRecord)
    }

    return {
      date: date.toISOString(),
      label: date.toLocaleDateString(undefined, { month: "short", day: "numeric" }),
      steps: null, distance_km: null, flights_climbed: null, walking_speed: null,
      walking_steadiness: null, walking_asymmetry_pct: null, walking_step_length: null,
      walking_double_support_pct: null, stair_ascent_speed: null,
      active_energy_burned: null, basal_energy_burned: null,
      headphone_audio_exposure: null, mindful_session_mins: null, time_in_daylight: null,
      total_sleep_hours: null, avg_blood_glucose_mgdl: null,
      dietary_carbohydrates_g: null, insulin_delivery_iu: null,
    }
  })
}

function CorrelationEngine({ data }: { data: TrendPoint[] }) {
  const [metricA, setMetricA] = useState<string>("steps")
  const [metricB, setMetricB] = useState<string>("none")

  const mA = availableMetrics.find(m => m.id === metricA)
  const mB = availableMetrics.find(m => m.id === metricB)

  const chartData = data.map((point) => ({
    label: point.label,
    valueA: mA ? point[metricA as keyof TrendPoint] : undefined,
    valueB: mB ? point[metricB as keyof TrendPoint] : undefined,
  }))

  const formatNumber = (value: number) => {
    if (value >= 1000) return `${Number((value / 1000).toFixed(1))}k`
    return Number.isInteger(value) ? value.toString() : value.toFixed(1)
  }

  const handleMetricAChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (e.target.value === "none" && metricB === "none") return;
    setMetricA(e.target.value)
  }

  const handleMetricBChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (e.target.value === "none" && metricA === "none") return;
    setMetricB(e.target.value)
  }

  return (
    <Card className="p-5">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
        <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>
          Compare Metrics
        </h2>
        <div className="flex items-center gap-3">
          <select 
            value={metricA} 
            onChange={handleMetricAChange}
            className="bg-[var(--linen)] border border-[var(--border-subtle)] text-[13px] text-[var(--deep-brown)] rounded-md px-2 py-1 outline-none focus:border-[var(--sage)]"
          >
            <option value="none">None (Bar)</option>
            {availableMetrics.map(m => <option key={m.id} value={m.id}>{m.label} (Bar)</option>)}
          </select>
          <span className="text-[var(--dust)] text-[13px]">vs</span>
          <select 
            value={metricB} 
            onChange={handleMetricBChange}
            className="bg-[var(--linen)] border border-[var(--border-subtle)] text-[13px] text-[var(--deep-brown)] rounded-md px-2 py-1 outline-none focus:border-[var(--amber)]"
          >
            <option value="none">None (Line)</option>
            {availableMetrics.map(m => <option key={m.id} value={m.id}>{m.label} (Line)</option>)}
          </select>
        </div>
      </div>
      <div className="h-[320px]">
        <ResponsiveContainer width="100%" height="100%" minWidth={1} minHeight={1}>
          <ComposedChart data={chartData} margin={{ top: 10, right: 10, bottom: 0, left: -20 }}>
            <CartesianGrid stroke="rgba(40,32,15,0.06)" vertical={false} />
            <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "var(--dust)" }} minTickGap={20} />
            
            {mA && <YAxis yAxisId="left" tickFormatter={formatNumber} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: mA.color }} orientation="left" />}
            {mB && <YAxis yAxisId="right" tickFormatter={formatNumber} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: mB.color }} orientation="right" />}
            
            <Tooltip
              cursor={{ fill: "rgba(40,32,15,0.04)" }}
              contentStyle={{ background: "var(--warm-white)", border: "1px solid var(--border-subtle)", borderRadius: 8, fontSize: 13 }}
            />
            {mA && <Bar yAxisId="left" dataKey="valueA" name={mA.label} fill={mA.color} radius={[4, 4, 0, 0]} maxBarSize={40} />}
            {mB && <Line yAxisId="right" type="monotone" dataKey="valueB" name={mB.label} stroke={mB.color} strokeWidth={3} dot={{ r: 4, fill: mB.color }} activeDot={{ r: 6 }} connectNulls={false} />}
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </Card>
  )
}

function ReportDatePicker({
  reports,
  selectedId,
  onSelect,
}: {
  reports: AIReport[]
  selectedId: number | null
  onSelect: (id: number) => void
}) {
  const [open, setOpen] = useState(false)
  const [viewDate, setViewDate] = useState(new Date())
  const calendarRef = useRef<HTMLDivElement>(null)

  const reportDates = new Set(
    reports.map((r) => {
      const d = new Date(r.created_at)
      return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
    })
  )

  const selectedDate = selectedId
    ? new Date(reports.find((r) => r.id === selectedId)?.created_at ?? "")
    : null

  const year = viewDate.getFullYear()
  const month = viewDate.getMonth()

  const firstDay = new Date(year, month, 1)
  const lastDay = new Date(year, month + 1, 0)
  const startOffset = firstDay.getDay()
  const daysInMonth = lastDay.getDate()

  const prevMonth = () => setViewDate(new Date(year, month - 1, 1))
  const nextMonth = () => setViewDate(new Date(year, month + 1, 1))

  const monthLabel = viewDate.toLocaleDateString(undefined, { month: "long", year: "numeric" })

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (calendarRef.current && !calendarRef.current.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    if (open) {
      document.addEventListener("mousedown", handleClickOutside)
      return () => document.removeEventListener("mousedown", handleClickOutside)
    }
  }, [open])

  const selectedReport = reports.find((r) => r.id === selectedId)
  const selectedLabel = selectedReport
    ? new Date(selectedReport.created_at).toLocaleDateString(undefined, { month: "short", day: "numeric" })
    : "Select date"

  return (
    <div className="relative mb-3 inline-block" ref={calendarRef}>
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className={`flex items-center gap-2 px-3 py-1.5 rounded-[8px] text-[13px] border transition-colors ${
          open
            ? 'bg-[var(--warm-white)] border-[var(--border-mid)] text-[var(--deep-brown)]'
            : 'bg-[var(--linen)] border-[var(--border-subtle)] text-[var(--deep-brown)] hover:border-[var(--border-mid)]'
        }`}
      >
        <span className="font-medium">{selectedLabel}</span>
        <ChevronDown className={`w-3.5 h-3.5 text-[var(--dust)] transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>

      {open && (
        <div className="absolute top-full left-0 mt-2 z-50 w-[260px] rounded-[10px] border border-[var(--border-subtle)] bg-[rgba(250,246,239,0.95)] backdrop-blur-md p-3 shadow-[0_12px_28px_rgba(40,32,15,0.14)]">
      <div className="flex items-center justify-between mb-2">
        <span className="text-[13px] font-medium text-[var(--deep-brown)]">{monthLabel}</span>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={prevMonth}
            className="p-1 rounded-[6px] text-[var(--dust)] hover:bg-[var(--soft-warm)] hover:text-[var(--deep-brown)] transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={nextMonth}
            className="p-1 rounded-[6px] text-[var(--dust)] hover:bg-[var(--soft-warm)] hover:text-[var(--deep-brown)] transition-colors"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1 text-center">
        {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => (
          <div key={`day-${i}`} className="text-[10px] text-[var(--dust)] py-1">
            {d}
          </div>
        ))}
        {Array.from({ length: startOffset }, (_, i) => (
          <div key={`empty-${i}`} />
        ))}
        {Array.from({ length: daysInMonth }, (_, i) => {
          const day = i + 1
          const dateKey = `${year}-${month}-${day}`
          const hasReport = reportDates.has(dateKey)
          const isSelected =
            selectedDate &&
            selectedDate.getDate() === day &&
            selectedDate.getMonth() === month &&
            selectedDate.getFullYear() === year

          return (
            <button
              key={day}
              type="button"
              onClick={() => {
                if (!hasReport) return
                const picked = new Date(year, month, day)
                picked.setHours(0, 0, 0, 0)
                let closest = reports[0]
                let minDiff = Infinity
                for (const report of reports) {
                  const d = new Date(report.created_at)
                  d.setHours(0, 0, 0, 0)
                  const diff = Math.abs(d.getTime() - picked.getTime())
                  if (diff < minDiff) {
                    minDiff = diff
                    closest = report
                  }
                }
                onSelect(closest.id)
              }}
              disabled={!hasReport}
              className={`relative rounded-[6px] py-1 text-[12px] transition-all ${
                isSelected
                  ? "bg-[var(--deep-brown)] text-[var(--warm-white)] font-medium"
                  : hasReport
                    ? "text-[var(--deep-brown)] hover:bg-[var(--soft-warm)] cursor-pointer"
                    : "text-[var(--border-mid)] cursor-default"
              }`}
            >
              {day}
              {hasReport && !isSelected && (
                <span className="absolute bottom-0.5 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full bg-[var(--sage)]" />
              )}
            </button>
          )
        })}
      </div>
        </div>
      )}
    </div>
  )
}

export function WellBeingTab() {
  const [days, setDays] = useState(1)
  const [healthRecords, setHealthRecords] = useState<HealthRecord[]>([])
  const [healthSummary, setHealthSummary] = useState<HealthRecord | null>(null)
  const [aiReports, setAiReports] = useState<AIReport[]>([])
  const [loading, setLoading] = useState(false)
  const [period, setPeriod] = useState('hourly')
  const [selectedReportId, setSelectedReportId] = useState<number | null>(null)
  const [chartType, setChartType] = useState<ChartType>("bar")
  const [syncing, setSyncing] = useState(false)
  const [syncMessage, setSyncMessage] = useState<string | null>(null)
  const [syncError, setSyncError] = useState<string | null>(null)
  const [activeModel, setActiveModel] = useState<string | null>('general')
  const [autoReportsRunning, setAutoReportsRunning] = useState(false)
  const autoReportsStarted = useRef(false)
  const fetchingCache = useRef<Record<string, boolean>>({})
  

  
  const [stateOfMindEntries, setStateOfMindEntries] = useState<StateOfMindEntry[]>([])

  async function fetchStateOfMind() {
    try {
      const res = await fetch("/api/well-being/state-of-mind")
      const data = await res.json()
      if (data.success) {
        setStateOfMindEntries(data.entries || [])
      }
    } catch (err) {
      console.error('Failed to fetch state of mind:', err)
    }
  }



  const [nutritionRec, setNutritionRec] = useState<string | null>(null)
  const [nutritionLoading, setNutritionLoading] = useState(false)
  const [nutritionQuery, setNutritionQuery] = useState("")
  const [nutritionContext, setNutritionContext] = useState<string>("")
  const [nutritionHistory, setNutritionHistory] = useState<any[]>([])
  const [isRecording, setIsRecording] = useState(false)
  const recognitionRef = useRef<any>(null)

  function toggleVoiceInput() {
    if (isRecording) {
      if (recognitionRef.current) recognitionRef.current.stop()
      setIsRecording(false)
      return
    }
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    if (!SpeechRecognition) {
      alert("Speech recognition is not supported in this browser.")
      return
    }
    const recognition = new SpeechRecognition()
    recognition.continuous = false
    recognition.interimResults = false
    recognition.lang = 'en-US'

    recognition.onstart = () => setIsRecording(true)
    recognition.onresult = (event: any) => {
      const transcript = event.results[0][0].transcript
      setNutritionQuery(prev => {
        const finalQuery = prev ? `${prev} ${transcript}` : transcript
        setTimeout(() => fetchNutritionAI(finalQuery, nutritionContext), 0)
        return finalQuery
      })
    }
    recognition.onerror = () => setIsRecording(false)
    recognition.onend = () => setIsRecording(false)

    recognitionRef.current = recognition
    recognition.start()
  }

  async function fetchNutritionHistory() {
    try {
      const res = await fetch("/api/well-being/nutrition-ai")
      const data = await res.json()
      if (data.success) setNutritionHistory(data.history || [])
    } catch (_) {}
  }

  async function deleteNutritionHistory(id: number) {
    try {
      await fetch("/api/well-being/nutrition-ai", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id })
      })
      fetchNutritionHistory()
    } catch (_) {}
  }

  async function fetchNutritionAI(query = "", context = "") {
    setNutritionLoading(true)
    setNutritionRec("") // clear it first, then append as stream arrives
    try {
      const res = await fetch("/api/well-being/nutrition-ai", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query, context })
      })
      if (!res.ok) {
        const errText = await res.text()
        setNutritionRec(`Error: ${res.status} - ${errText}`)
        return
      }
      const reader = res.body?.getReader()
      if (!reader) return
      const decoder = new TextDecoder()
      let text = ""
      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        text += decoder.decode(value, { stream: true })
        setNutritionRec(text)
      }
      // Refresh history after a new recommendation
      fetchNutritionHistory()
    } catch (err: any) {
      setNutritionRec(`Network error: ${err.message}`)
    } finally {
      setNutritionLoading(false)
    }
  }

  async function fetchHealthRecords() {
    try {
      const response = await fetch(`/api/well-being/health-records?days=${days}`)
      const data = await response.json()
      setHealthRecords(data.records || [])
      setHealthSummary(data.summary || null)
    } catch (error) {
      console.error('Failed to fetch health records:', error)
    }
  }

  async function fetchAIReportsForPeriod(reportPeriod = period, expert = activeModel, forceRefresh = false, background = false) {
    const cacheKey = `${reportPeriod}-${expert}`

    if (fetchingCache.current[cacheKey]) {
      setLoading(false)
      return
    }
    fetchingCache.current[cacheKey] = true

    if (!background) setLoading(true)
    try {
      const expertQuery = expert ? `&expert=${expert}` : ''
      const response = await fetch(`/api/well-being/ai-reports?period=${reportPeriod}${expertQuery}`)
      const data = await response.json()
      const reports = data.reports || []
      setAiReports(reports)
      setSelectedReportId(reports[0]?.id ?? null)
    } catch (error) {
      console.error('Failed to fetch AI reports:', error)
    } finally {
      setLoading(false)
      fetchingCache.current[cacheKey] = false
    }
  }

  async function runAutomaticSignalReports(reportPeriod = period, expert = activeModel) {
    if (autoReportsStarted.current) return
    autoReportsStarted.current = true
    setAutoReportsRunning(true)
    try {
      await fetch('/api/well-being/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ auto: true, background: true })
      })
      window.setTimeout(() => {
        void fetchAIReportsForPeriod(reportPeriod, expert, true, true)
      }, 5000)
    } catch (error) {
      console.error('Failed to run automatic signal reports:', error)
    } finally {
      setAutoReportsRunning(false)
    }
  }

  useEffect(() => {
    fetchHealthRecords()

    fetchStateOfMind()
    fetchNutritionHistory()
  }, [days])

  useEffect(() => {
    fetchAIReportsForPeriod(period, activeModel)
  }, [period, activeModel])

  useEffect(() => {
    void runAutomaticSignalReports(period, activeModel)
  }, [])

  async function generateExpertReport() {
    setLoading(true)
    try {
      await fetch('/api/well-being/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ period, expert: activeModel, force: true })
      })
      await fetchAIReportsForPeriod(period, activeModel, true)
    } catch (e) {
      console.error('Failed to generate report', e)
    } finally {
      setLoading(false)
    }
  }

  // Suppress the known harmless Recharts ResponsiveContainer warning
  useEffect(() => {
    const originalWarn = console.warn
    console.warn = (...args) => {
      if (typeof args[0] === 'string' && args[0].includes('The width(-1) and height(-1)')) {
        return
      }
      originalWarn(...args)
    }
    return () => {
      console.warn = originalWarn
    }
  }, [])

  const visibleHealthRecords = healthRecords.filter(
    (record) => record.source_file === "daily_health.txt" || record.source_file === "healthkit",
  )
  const trendSeries = buildTrendSeries(visibleHealthRecords, days)

  const avgRecord = healthSummary
  const latestRecord = visibleHealthRecords.at(-1) || avgRecord
  const selectedReport = aiReports.find((report) => report.id === selectedReportId) ?? aiReports[0]
  const selectedReportDate = selectedReport ? new Date(selectedReport.created_at).toLocaleDateString() : null

  const isDaily = days === 1
  const metricPrefix = isDaily ? "Daily" : "Avg"

  // Helper to find the latest non-null value for a specific metric key from the records
  const getLatestNonNull = (key: keyof HealthRecord) => {
    for (let i = visibleHealthRecords.length - 1; i >= 0; i--) {
      const val = visibleHealthRecords[i][key]
      if (val !== null && val !== undefined) return Number(val)
    }
    return null
  }

  function renderDeltaKpi(label: string, mainValue: number | null, comparisonValue: number | null, unit?: string) {
    const valStr = mainValue !== null ? (mainValue >= 1000 ? `${(mainValue/1000).toFixed(1)}k` : Number.isInteger(mainValue) ? mainValue.toString() : mainValue.toFixed(1)) : 'N/A'
    const displayVal = unit && mainValue !== null ? `${valStr} ${unit}` : valStr

    let trend: number | undefined = undefined
    let trendLabel: string | undefined = undefined

    if (isDaily && mainValue !== null && comparisonValue !== null && comparisonValue > 0) {
      const diff = mainValue - comparisonValue
      const pct = (diff / comparisonValue) * 100
      if (Math.abs(pct) > 1) {
        trend = Number(pct.toFixed(1))
        trendLabel = "vs avg"
      }
    }

    return <KPIMetric label={label} value={displayVal} trend={trend} trendLabel={trendLabel} />
  }

  const renderSignalIntelligence = () => {
    return (
      <section className="h-full flex flex-col">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-[10px] bg-gradient-to-br from-[#C4956A] to-[#A0764E] flex items-center justify-center shadow-[var(--shadow-sm)]">
              <Activity className="w-4 h-4 text-[#FAF6EF]" />
            </div>
            <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Health Insights</h2>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex rounded-[8px] border border-[var(--border-subtle)] bg-[var(--linen)] p-1">
              {reportPeriods.map((reportPeriod) => (
                <button
                  key={reportPeriod.value}
                  type="button"
                  onClick={() => setPeriod(reportPeriod.value)}
                  className={`px-3 py-1.5 rounded-[6px] text-[13px] transition-colors ${
                    period === reportPeriod.value
                      ? "bg-[var(--warm-white)] text-[var(--deep-brown)] shadow-[var(--shadow-sm)]"
                      : "text-[var(--mid-brown)] hover:text-[var(--deep-brown)]"
                  }`}
                >
                  {reportPeriod.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 mb-4 overflow-x-auto pb-1 hide-scrollbar">
          <span className="text-[10px] uppercase tracking-wider font-semibold text-[var(--dust)] mr-1 shrink-0">Active Models:</span>
          <button 
            type="button" 
            onClick={() => setActiveModel('general')}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-[4px] border transition-all active:scale-95 cursor-pointer ${activeModel === 'general' ? 'bg-[var(--deep-brown)] border-[var(--deep-brown)]' : 'bg-[var(--linen)] border-[var(--border-subtle)] hover:bg-[var(--warm-white)] hover:border-[var(--mid-brown)] hover:shadow-[var(--shadow-sm)]'}`}
          >
            <Sparkles className={`w-3 h-3 ${activeModel === 'general' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`} />
            <span className={`text-[11px] font-medium whitespace-nowrap ${activeModel === 'general' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`}>General</span>
          </button>
          <button 
            type="button" 
            onClick={() => setActiveModel('data_scientist')}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-[4px] border transition-all active:scale-95 cursor-pointer ${activeModel === 'data_scientist' ? 'bg-[var(--deep-brown)] border-[var(--deep-brown)]' : 'bg-[var(--linen)] border-[var(--border-subtle)] hover:bg-[var(--warm-white)] hover:border-[var(--mid-brown)] hover:shadow-[var(--shadow-sm)]'}`}
          >
            <Database className={`w-3 h-3 ${activeModel === 'data_scientist' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`} />
            <span className={`text-[11px] font-medium whitespace-nowrap ${activeModel === 'data_scientist' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`}>Data Scientist</span>
          </button>
          <button 
            type="button" 
            onClick={() => setActiveModel('endocrinologist')}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-[4px] border transition-all active:scale-95 cursor-pointer ${activeModel === 'endocrinologist' ? 'bg-[var(--accent-danger)] border-[var(--accent-danger)]' : 'bg-[var(--linen)] border-[var(--border-subtle)] hover:bg-[var(--warm-white)] hover:border-[var(--accent-danger)] hover:shadow-[var(--shadow-sm)]'}`}
          >
            <Stethoscope className={`w-3 h-3 ${activeModel === 'endocrinologist' ? 'text-[var(--warm-white)]' : 'text-[var(--accent-danger)]'}`} />
            <span className={`text-[11px] font-medium whitespace-nowrap ${activeModel === 'endocrinologist' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`}>Endocrinologist</span>
          </button>
          <button 
            type="button" 
            onClick={() => setActiveModel('nutritionist')}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-[4px] border transition-all active:scale-95 cursor-pointer ${activeModel === 'nutritionist' ? 'bg-[var(--amber)] border-[var(--amber)]' : 'bg-[var(--linen)] border-[var(--border-subtle)] hover:bg-[var(--warm-white)] hover:border-[var(--amber)] hover:shadow-[var(--shadow-sm)]'}`}
          >
            <Apple className={`w-3 h-3 ${activeModel === 'nutritionist' ? 'text-[#FAF6EF]' : 'text-[var(--amber)]'}`} />
            <span className={`text-[11px] font-medium whitespace-nowrap ${activeModel === 'nutritionist' ? 'text-[#FAF6EF]' : 'text-[var(--deep-brown)]'}`}>Nutritionist</span>
          </button>
          <button 
            type="button" 
            onClick={() => setActiveModel('strength_coach')}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-[4px] border transition-all active:scale-95 cursor-pointer ${activeModel === 'strength_coach' ? 'bg-[var(--sage)] border-[var(--sage)]' : 'bg-[var(--linen)] border-[var(--border-subtle)] hover:bg-[var(--warm-white)] hover:border-[var(--sage)] hover:shadow-[var(--shadow-sm)]'}`}
          >
            <Dumbbell className={`w-3 h-3 ${activeModel === 'strength_coach' ? 'text-[var(--warm-white)]' : 'text-[var(--sage)]'}`} />
            <span className={`text-[11px] font-medium whitespace-nowrap ${activeModel === 'strength_coach' ? 'text-[var(--warm-white)]' : 'text-[var(--deep-brown)]'}`}>Strength Coach</span>
          </button>
        </div>
        {autoReportsRunning && (
          <div className="mb-3 text-[11px] text-[var(--dust)]">
            Signal reports are generating in the background.
          </div>
        )}

        {loading ? (
          <Card className="flex-1 flex items-center justify-center p-6 min-h-[200px]">
            <div className="text-center text-[var(--dust)] flex flex-col items-center gap-2">
              <Loader2 className="w-6 h-6 animate-spin text-[var(--sage)]" />
              <span>Loading AI reports...</span>
            </div>
          </Card>
        ) : aiReports.length === 0 ? (
          <Card className="flex-1 p-6 text-center min-h-[200px] flex flex-col items-center justify-center">
            <div className="text-center text-[var(--dust)] max-w-[280px]">
              {period === "hourly" ? (
                <p>
                  No hourly reports yet for {activeModel ? activeModel.replace('_', ' ') : 'this period'}.
                </p>
              ) : (
                <p>{`No ${period} reports found yet for ${activeModel ? activeModel.replace('_', ' ') : 'this period'}.`}</p>
              )}
              {activeModel && (
                <button type="button" onClick={generateExpertReport} className="mt-4 px-4 py-2 bg-[var(--deep-brown)] text-[var(--warm-white)] text-[12px] rounded-[6px] hover:opacity-90 transition-opacity">
                  Generate as {activeModel.replace('_', ' ')}
                </button>
              )}
            </div>
          </Card>
        ) : (
          <div className="transition-all duration-300 ease-out flex-1 flex flex-col">
            <Card key={`${period}-${selectedReport?.id}`} className="mb-3 animate-report-in p-4 flex-1 overflow-wrap break-all overflow-x-hidden">
              <div className="flex items-center justify-between mb-4 pb-2 border-b border-[var(--border-subtle)]">
                  <h4 className="text-[11px] uppercase tracking-widest text-[var(--deep-brown)] font-semibold flex items-center gap-2">
                    <Sparkles className="w-3.5 h-3.5 text-[var(--sage)]" />
                    {period.toUpperCase()} REPORT
                    {activeModel && <span className="text-[10px] bg-[var(--soft-warm)] px-2 py-0.5 rounded text-[var(--deep-brown)]">{activeModel.replace('_', ' ')}</span>}
                  </h4>
                  <div className="flex items-center gap-3">
                    <span className="text-[10px] text-[var(--dust)]">{selectedReport ? new Date(selectedReport.created_at).toLocaleString() : ''}</span>
                  </div>
              </div>
              <ReportMarkdown text={selectedReport?.report_text ?? ""} activeModel={activeModel} />
            </Card>
          </div>
        )}
      </section>
    )
  }

  const renderNutritionEngine = () => {
    return (
      <section>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-[10px] bg-gradient-to-br from-[var(--sage)] to-[#5a7a57] flex items-center justify-center shadow-[var(--shadow-sm)]">
              <Leaf className="w-5 h-5 text-[#FAF6EF]" strokeWidth={2.5} />
            </div>
            <div>
              <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>AI Nutritionist</h2>
            </div>
          </div>
          {nutritionHistory.length > 0 && (
            <div className="flex items-center gap-1 text-[10px] text-[var(--dust)]">
              <History className="w-3 h-3" />
              <span>{nutritionHistory.length} past</span>
            </div>
          )}
        </div>

        <Card className="bg-[var(--warm-white)] border-[var(--border-subtle)] shadow-[var(--shadow-sm)] overflow-hidden">
          {/* Meal Context Selector */}
          <div className="p-4 pb-3 border-b border-[var(--border-subtle)] bg-gradient-to-r from-[var(--warm-white)] to-[var(--linen)]">
            <span className="text-[12px] uppercase tracking-widest text-[var(--dust)] font-semibold block mb-2.5">What are you looking for?</span>
            <div className="flex flex-wrap gap-2">
              {[
                { id: 'breakfast', label: 'Breakfast', icon: <Sunrise className="w-3.5 h-3.5" />, emoji: '🌅' },
                { id: 'lunch', label: 'Lunch', icon: <Sun className="w-3.5 h-3.5" />, emoji: '🌞' },
                { id: 'dinner', label: 'Dinner', icon: <Sunset className="w-3.5 h-3.5" />, emoji: '🌙' },
                { id: 'pre-workout', label: 'Pre-Workout', icon: <Zap className="w-3.5 h-3.5" />, emoji: '💪' },
                { id: 'post-workout recovery', label: 'Recovery', icon: <Leaf className="w-3.5 h-3.5" />, emoji: '🧘' },
                { id: 'healthy snack', label: 'Snack', icon: <Cookie className="w-3.5 h-3.5" />, emoji: '🍎' },
                { id: 'sleep-promoting evening food', label: 'Before Bed', icon: <Moon className="w-3.5 h-3.5" />, emoji: '😴' },
                { id: 'low glycemic index meal', label: 'Low GI', icon: <Flame className="w-3.5 h-3.5" />, emoji: '🩸' },
              ].map(ctx => (
                <button
                  key={ctx.id}
                  type="button"
                  onClick={() => setNutritionContext(prev => prev === ctx.id ? '' : ctx.id)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[13px] font-medium border transition-all ${
                    nutritionContext === ctx.id
                      ? 'bg-[var(--sage)] text-[#FAF6EF] border-[var(--sage)] shadow-[0_2px_8px_rgba(125,147,122,0.25)]'
                      : 'bg-[var(--warm-white)] text-[var(--mid-brown)] border-[var(--border-subtle)] hover:border-[var(--sage)] hover:text-[var(--sage)] hover:bg-[rgba(125,147,122,0.04)]'
                  }`}
                >
                  <span className="flex items-center justify-center opacity-80">{ctx.icon}</span>
                  {ctx.label}
                </button>
              ))}
            </div>
          </div>


          {/* Parsed Meal Cards */}
          {nutritionRec && (() => {
            const meals: { name: string; why: string; macros: string; gi: string; prep: string }[] = []
            let insight = ''
            let currentMeal: Partial<typeof meals[0]> = {}
            
            for (const line of nutritionRec.split('\n')) {
              const trimmed = line.trim()
              if (!trimmed) continue
              if (trimmed.startsWith('[MEAL_REC]')) {
                if (currentMeal.name) meals.push(currentMeal as typeof meals[0])
                currentMeal = { name: '', why: '', macros: '', gi: '', prep: '' }
              } else if (trimmed.startsWith('**Name:**')) {
                currentMeal.name = trimmed.replace('**Name:**', '').replace(/\*\*/g, '').trim()
              } else if (trimmed.startsWith('**Why:**')) {
                currentMeal.why = trimmed.replace('**Why:**', '').replace(/\*\*/g, '').trim()
              } else if (trimmed.startsWith('**Macros:**')) {
                currentMeal.macros = trimmed.replace('**Macros:**', '').replace(/\*\*/g, '').trim()
              } else if (trimmed.startsWith('**GI Score:**')) {
                currentMeal.gi = trimmed.replace('**GI Score:**', '').replace(/\*\*/g, '').trim()
              } else if (trimmed.startsWith('**Prep:**')) {
                currentMeal.prep = trimmed.replace('**Prep:**', '').replace(/\*\*/g, '').trim()
              } else if (trimmed.startsWith('[NUTRITION_INSIGHT]')) {
                insight = trimmed.replace('[NUTRITION_INSIGHT]', '').trim()
              }
            }
            if (currentMeal.name) meals.push(currentMeal as typeof meals[0])

            if (meals.length === 0 && nutritionLoading) {
              return (
                <div className="px-4 pb-4">
                  <div className="bg-[var(--linen)] rounded-[10px] p-4 border border-[var(--border-subtle)]">
                    <div className="flex items-center gap-2 mb-2">
                      <Loader2 className="w-3.5 h-3.5 animate-spin text-[var(--sage)]" />
                      <span className="text-[11px] text-[var(--dust)] uppercase tracking-wider font-semibold">Generating recommendations...</span>
                    </div>
                    <div className="font-mono text-[11px] text-[var(--mid-brown)] leading-relaxed whitespace-pre-wrap max-h-[120px] overflow-y-auto">
                      {nutritionRec}
                    </div>
                  </div>
                </div>
              )
            }

            if (meals.length === 0 && !nutritionLoading && nutritionRec) {
              return (
                <div className="px-4 pb-4">
                  <div className="font-mono text-[12px] leading-relaxed bg-[var(--linen)] text-[var(--mid-brown)] p-4 rounded-[10px] border border-[var(--border-subtle)] max-h-[300px] overflow-y-auto">
                    {nutritionRec.split('\n').map((line, i) => {
                      const t = line.trim()
                      if (!t) return null
                      return <div key={i} className="mb-1">{t.replace(/\*\*/g, '')}</div>
                    })}
                  </div>
                </div>
              )
            }

            const giColors: Record<string, { bg: string; text: string; border: string }> = {
              low: { bg: 'rgba(125,147,122,0.1)', text: 'var(--sage)', border: 'rgba(125,147,122,0.25)' },
              medium: { bg: 'rgba(184,132,90,0.1)', text: 'var(--amber)', border: 'rgba(184,132,90,0.25)' },
              high: { bg: 'rgba(199,91,91,0.1)', text: 'var(--accent-danger)', border: 'rgba(199,91,91,0.25)' },
            }
            const mealEmojis = ['🥗', '🍲', '🥘', '🍛', '🥙', '🍜']

            return (
              <div className="px-4 pb-4 space-y-3">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {meals.map((meal, idx) => {
                    const giKey = (meal.gi || '').toLowerCase().includes('low') ? 'low' : (meal.gi || '').toLowerCase().includes('high') ? 'high' : 'medium'
                    const giStyle = giColors[giKey]
                    const macrosParts = meal.macros.split(/[|,]/).map(s => s.trim()).filter(Boolean)

                    return (
                      <div
                        key={idx}
                        className="bg-[var(--linen)] rounded-[12px] border border-[var(--border-subtle)] p-4 hover:shadow-[var(--shadow-md)] transition-shadow animate-report-in flex flex-col justify-between"
                      >
                        <div>
                          <div className="flex items-start justify-between gap-3 mb-2">
                            <div className="flex items-center gap-2.5 flex-1 min-w-0">
                              <span className="text-[20px] shrink-0">{mealEmojis[idx % mealEmojis.length]}</span>
                              <div className="min-w-0">
                                <h4 className="text-[14px] font-semibold text-[var(--deep-brown)] truncate">{meal.name || 'Loading...'}</h4>
                              </div>
                            </div>
                            {meal.gi && (
                              <span
                                className="shrink-0 px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border"
                                style={{ background: giStyle.bg, color: giStyle.text, borderColor: giStyle.border }}
                              >
                                {meal.gi}
                              </span>
                            )}
                          </div>

                          {meal.why && (
                            <p className="text-[12px] text-[var(--mid-brown)] italic mb-3 leading-relaxed pl-[30px]">
                              &ldquo;{meal.why}&rdquo;
                            </p>
                          )}
                        </div>

                        <div>
                          {macrosParts.length > 0 && (
                            <div className="flex flex-wrap gap-1.5 mb-3 pl-[30px]">
                              {macrosParts.map((macro, mi) => (
                                <span
                                  key={mi}
                                  className="px-2 py-0.5 bg-[var(--warm-white)] border border-[var(--border-subtle)] rounded-full text-[10px] text-[var(--deep-brown)] font-medium"
                                >
                                  {macro}
                                </span>
                              ))}
                            </div>
                          )}

                          {meal.prep && (
                            <div className="flex items-start gap-2 pl-[30px] border-t border-[var(--border-subtle)] pt-2.5">
                              <span className="text-[11px] text-[var(--dust)] shrink-0 mt-px">📋</span>
                              <p className="text-[12px] text-[var(--mid-brown)] leading-relaxed">{meal.prep}</p>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>

                {insight && (
                  <div className="flex items-start gap-3 bg-gradient-to-r from-[rgba(184,132,90,0.08)] to-[rgba(184,132,90,0.03)] border border-[rgba(184,132,90,0.15)] rounded-[10px] p-3.5">
                    <span className="text-[16px] shrink-0">💡</span>
                    <div>
                      <span className="text-[10px] uppercase tracking-widest text-[var(--amber)] font-bold block mb-0.5">Metabolic Insight</span>
                      <p className="text-[12px] text-[var(--deep-brown)] leading-relaxed">{insight}</p>
                    </div>
                  </div>
                )}
              </div>
            )
          })()}

          {/* Recommendation History */}
          {nutritionHistory.length > 0 && (
            <div className="border-t border-[var(--border-subtle)] px-4 py-4 bg-[var(--linen)] bg-opacity-50">
              <div className="flex items-center gap-1.5 mb-3">
                <Clock className="w-4 h-4 text-[var(--dust)]" />
                <span className="text-[12px] uppercase tracking-widest text-[var(--dust)] font-semibold">Recent Recommendations</span>
              </div>
              <div className="space-y-2 max-h-[160px] overflow-y-auto pr-2">
                {nutritionHistory.map((rec: any) => {
                  const ts = new Date(rec.created_at)
                  const timeAgo = (() => {
                    const mins = Math.floor((Date.now() - ts.getTime()) / 60000)
                    if (mins < 60) return `${mins}m ago`
                    const hrs = Math.floor(mins / 60)
                    if (hrs < 24) return `${hrs}h ago`
                    return `${Math.floor(hrs / 24)}d ago`
                  })()
                  return (
                    <div key={rec.id} className="group flex items-center justify-between gap-3 bg-[var(--warm-white)] border border-[var(--border-subtle)] rounded-[8px] p-2.5 shadow-sm transition-all hover:border-[var(--sage)]">
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        <span className="text-[var(--dust)] font-mono shrink-0 text-[11px] w-[48px]">{timeAgo}</span>
                        <div className="flex flex-col min-w-0">
                          <span className="text-[var(--deep-brown)] truncate font-medium text-[13px]">{rec.meal_names || 'Recommendation'}</span>
                          {rec.meal_context && (
                            <span className="text-[10px] text-[var(--sage)] font-medium uppercase tracking-wide">{rec.meal_context}</span>
                          )}
                        </div>
                      </div>
                      <button 
                        onClick={() => deleteNutritionHistory(rec.id)}
                        className="p-1.5 text-[var(--dust)] hover:text-[var(--accent-danger)] hover:bg-[rgba(199,91,91,0.1)] rounded-md transition-colors opacity-0 group-hover:opacity-100"
                        title="Delete recommendation"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          {/* Query Input + Generate Button */}
          <div className="p-4 bg-[var(--warm-white)] border-t border-[var(--border-subtle)]">
            <div className="flex gap-2">
              <input
                type="text"
                value={nutritionQuery}
                onChange={(e) => setNutritionQuery(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') fetchNutritionAI(nutritionQuery, nutritionContext)
                }}
                placeholder={nutritionContext ? `Any specifics for ${nutritionContext}? (optional)` : "What should I eat? Any cravings or constraints?"}
                className="flex-1 bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--sage)] transition-colors"
              />
              <button
                type="button"
                onClick={toggleVoiceInput}
                className={`w-10 h-10 rounded-[8px] border transition-all flex items-center justify-center shrink-0 ${
                  isRecording 
                    ? 'border-[var(--accent-danger)] text-[var(--accent-danger)] bg-[rgba(199,91,91,0.1)] shadow-[0_2px_8px_rgba(199,91,91,0.2)]' 
                    : 'bg-[var(--warm-white)] border-[var(--border-subtle)] text-[var(--mid-brown)] hover:text-[var(--sage)] hover:border-[var(--sage)] hover:bg-[rgba(125,147,122,0.04)]'
                }`}
                title={isRecording ? "Stop recording" : "Voice input"}
              >
                {isRecording ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
              </button>
              <button
                type="button"
                onClick={() => fetchNutritionAI(nutritionQuery, nutritionContext)}
                disabled={nutritionLoading}
                className="w-10 h-10 bg-gradient-to-br from-[var(--sage)] to-[#5a7a57] text-[#FAF6EF] rounded-[8px] transition-all hover:opacity-90 disabled:opacity-50 flex items-center justify-center shrink-0 shadow-[0_2px_8px_rgba(125,147,122,0.3)]"
                title="Generate Recommendation"
              >
                {nutritionLoading ? (
                  <Loader2 className="w-5 h-5 animate-spin" />
                ) : (
                  <Send className="w-5 h-5" />
                )}
              </button>
            </div>
          </div>
        </Card>
      </section>
    )
  }



  const renderDiabetesManagement = () => {
    return (
      <section>
        <div className="flex items-center gap-2.5 mb-4">
          <div className="w-8 h-8 rounded-[10px] bg-gradient-to-br from-[#E07A5F] to-[#C4503D] flex items-center justify-center shadow-[var(--shadow-sm)]">
            <Stethoscope className="w-4 h-4 text-[#FAF6EF]" />
          </div>
          <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Diabetes Management</h2>
        </div>
        <Card className="bg-[var(--warm-white)] p-5 border-[var(--border-subtle)] shadow-[var(--shadow-sm)]">
          <div className="flex flex-col gap-4 flex-1">
            <div className="flex items-center gap-2 pb-3 border-b border-[var(--border-subtle)]">
              <span className="text-[18px]">🩸</span>
              <h3 className="text-[14px] font-medium text-[var(--deep-brown)]">GLUCOSE</h3>
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="text-[11px] uppercase tracking-widest text-[var(--dust)] mb-1">Current</div>
                <div className="flex items-baseline gap-2">
                  <span className="text-[28px] font-light text-[var(--deep-brown)]">
                    {healthRecords[0]?.avg_blood_glucose_mgdl ? healthRecords[0].avg_blood_glucose_mgdl.toFixed(1) : 'N/A'}
                  </span>
                  <span className="text-[12px] text-[var(--mid-brown)]">mg/dL</span>
                </div>
                {healthRecords[0]?.avg_blood_glucose_mgdl && healthRecords[0].avg_blood_glucose_mgdl >= 70 && healthRecords[0].avg_blood_glucose_mgdl <= 180 ? (
                  <div className="text-[12px] font-medium text-[var(--sage)] mt-1">✅ In Range</div>
                ) : healthRecords[0]?.avg_blood_glucose_mgdl ? (
                  <div className="text-[12px] font-medium text-[var(--accent-danger)] mt-1">⚠️ Out of Range</div>
                ) : null}
              </div>
              <div>
                <div className="text-[11px] uppercase tracking-widest text-[var(--dust)] mb-1">Dietary Carbs</div>
                <div className="flex items-baseline gap-2">
                  <span className="text-[28px] font-light text-[var(--deep-brown)]">
                    {healthRecords[0]?.dietary_carbohydrates_g ?? '0'}
                  </span>
                  <span className="text-[12px] text-[var(--mid-brown)]">g</span>
                </div>
              </div>
            </div>

            <div className="mt-2 p-3 bg-[var(--linen)] rounded-[6px] border border-[var(--border-subtle)]">
              <h4 className="text-[11px] font-semibold tracking-wider text-[var(--deep-brown)] uppercase mb-2">Today's Summary</h4>
              <div className="space-y-2">
                <div className="flex justify-between text-[12px]">
                  <span className="text-[var(--mid-brown)]">Time in Range (70-180)</span>
                  <span className="font-medium text-[var(--sage)]">
                    {healthRecords[0]?.avg_blood_glucose_mgdl && healthRecords[0].avg_blood_glucose_mgdl >= 70 && healthRecords[0].avg_blood_glucose_mgdl <= 180 ? '100% ✅' : 'N/A'}
                  </span>
                </div>
                <div className="flex justify-between text-[12px]">
                  <span className="text-[var(--mid-brown)]">Time High (&gt;180)</span>
                  <span className="font-medium text-[var(--accent-danger)]">
                    {healthRecords[0]?.avg_blood_glucose_mgdl && healthRecords[0].avg_blood_glucose_mgdl > 180 ? '100% ⚠️' : '0%'}
                  </span>
                </div>
                <div className="flex justify-between text-[12px]">
                  <span className="text-[var(--mid-brown)]">Insulin Delivery</span>
                  <span className="font-medium text-[var(--deep-brown)]">
                    {healthRecords[0]?.insulin_delivery_iu ?? '0'} IU
                  </span>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </section>
    )
  }

  // Derive State of Mind status for the compact header badge
  const stateOfMindStatus = (() => {
    if (stateOfMindEntries.length === 0) return null
    const latest = stateOfMindEntries[0]
    const labels = latest.labels.split(',').map(l => l.trim()).filter(Boolean)
    const firstLabel = labels[0]?.toLowerCase() || ''
    let emoji = '🧠'
    if (firstLabel.includes('happy') || firstLabel.includes('joy') || firstLabel.includes('pleasant')) emoji = '😊'
    else if (firstLabel.includes('calm') || firstLabel.includes('peace') || firstLabel.includes('content')) emoji = '😌'
    else if (firstLabel.includes('anxious') || firstLabel.includes('anxiety') || firstLabel.includes('worried')) emoji = '😰'
    else if (firstLabel.includes('sad') || firstLabel.includes('depress') || firstLabel.includes('down')) emoji = '😔'
    else if (firstLabel.includes('stress') || firstLabel.includes('tense') || firstLabel.includes('overwhelm')) emoji = '😓'
    else if (firstLabel.includes('energi') || firstLabel.includes('excit') || firstLabel.includes('motivated')) emoji = '⚡️'
    else if (firstLabel.includes('tired') || firstLabel.includes('fatigue') || firstLabel.includes('exhaust')) emoji = '😴'
    else if (firstLabel.includes('focus') || firstLabel.includes('concentrat') || firstLabel.includes('flow')) emoji = '🎯'
    else if (firstLabel.includes('grat') || firstLabel.includes('thank')) emoji = '🙏'
    else if (firstLabel.includes('indifferent') || firstLabel.includes('neutral')) emoji = '😐'
    const ts = new Date(latest.timestamp.replace(' ', 'T'))
    const mins = Math.floor((Date.now() - ts.getTime()) / 60000)
    const timeAgo = mins < 60 ? `${mins}m ago` : mins < 1440 ? `${Math.floor(mins / 60)}h ago` : `${Math.floor(mins / 1440)}d ago`
    return { emoji, labels, timeAgo }
  })()

  return (
    <div className="space-y-6">
      {/* Time Period Selector + State of Mind Status */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          {/* State of Mind — compact inline status */}
          {stateOfMindStatus && (
            <div className="flex items-center gap-2 px-3 py-1.5 bg-[var(--warm-white)] border border-[var(--border-subtle)] rounded-[8px] shadow-[var(--shadow-sm)]">
              <span className="text-[16px] leading-none">{stateOfMindStatus.emoji}</span>
              <div className="flex items-center gap-1.5">
                {stateOfMindStatus.labels.slice(0, 2).map((label, i) => (
                  <span key={i} className="text-[12px] font-medium text-[var(--deep-brown)]">{label}</span>
                ))}
              </div>
              <span className="text-[10px] text-[var(--dust)]">{stateOfMindStatus.timeAgo}</span>
            </div>
          )}

          <div className="flex items-center gap-1 border-l border-[var(--border-subtle)] pl-3">
            {rangeOptions
              .filter((opt) => opt.days !== 90)
              .map((opt) => (
                <button
                  key={opt.days}
                  onClick={() => setDays(opt.days)}
                  className={`px-3 py-1.5 rounded text-[13px] ${
                    days === opt.days
                      ? 'bg-[var(--soft-warm)] text-[var(--deep-brown)]'
                      : 'text-[var(--mid-brown)] hover:bg-[var(--soft-warm)]'
                  }`}
                >
                  {opt.label}
                </button>
              ))}
          </div>
        </div>
        <button
          onClick={async () => {
            setSyncing(true)
            setSyncMessage(null)
            setSyncError(null)
            try {
              const res = await fetch('/api/well-being/sync', { method: 'POST' })
              const data = await res.json()
              if (data.success) {
                setSyncMessage('Health data synced successfully')
                await fetchHealthRecords()
              } else {
                setSyncError(data.error || 'Sync failed')
              }
            } catch (err: any) {
              setSyncError('Network error: ' + (err.message || 'unknown error'))
            } finally {
              setSyncing(false)
              setTimeout(() => { setSyncMessage(null); setSyncError(null) }, 6000)
            }
          }}
          disabled={syncing}
          className="flex items-center gap-2 px-3 sm:px-4 py-2 bg-[var(--sage)] text-[#FAF6EF] rounded-[8px] text-[12px] sm:text-[13px] font-light hover:opacity-90 transition-all disabled:opacity-50 shrink-0"
        >
          <RefreshCw className={`w-4 h-4 ${syncing ? 'animate-spin' : ''}`} />
          {syncing ? 'Syncing...' : 'Sync Health Data'}
        </button>
      </div>

      {syncMessage && (
        <div className="px-4 py-2 bg-[rgba(125,147,122,0.08)] border border-[rgba(125,147,122,0.15)] rounded-[8px] text-[13px] text-[var(--sage)]">
          {syncMessage}
        </div>
      )}
      {syncError && (
        <div className="px-4 py-2 bg-[rgba(199,91,91,0.08)] border border-[rgba(199,91,91,0.15)] rounded-[8px] text-[13px] text-[var(--accent-danger)]">
          {syncError}
        </div>
      )}

      {/* ═══ Categorized Health Metrics Bento Grid ═══ */}

      {/* 🏃 Physical Activity */}
      <section>
        <Card className="p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <div className="w-7 h-7 rounded-[8px] bg-gradient-to-br from-[var(--sage)] to-[#5a7a57] flex items-center justify-center">
              <Flame className="w-4 h-4 text-[#FAF6EF]" strokeWidth={2.5} />
            </div>
            <h3 className="text-[15px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Physical Activity</h3>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:gap-4 sm:grid-cols-3 lg:grid-cols-6">
            {renderDeltaKpi(`${metricPrefix} Steps`, isDaily ? getLatestNonNull('steps') : avgRecord?.steps ?? null, isDaily ? avgRecord?.steps ?? null : null)}
            {renderDeltaKpi(`${metricPrefix} Distance`, isDaily ? getLatestNonNull('distance_km') : avgRecord?.distance_km ?? null, isDaily ? avgRecord?.distance_km ?? null : null, "km")}
            {renderDeltaKpi(`${metricPrefix} Flights`, isDaily ? getLatestNonNull('flights_climbed') : avgRecord?.flights_climbed ?? null, isDaily ? avgRecord?.flights_climbed ?? null : null)}
            {renderDeltaKpi(`${metricPrefix} Active Cals`, isDaily ? getLatestNonNull('active_energy_burned') : avgRecord?.active_energy_burned ?? null, isDaily ? avgRecord?.active_energy_burned ?? null : null, "kcal")}
            {renderDeltaKpi(`${metricPrefix} Basal Cals`, isDaily ? getLatestNonNull('basal_energy_burned') : avgRecord?.basal_energy_burned ?? null, isDaily ? avgRecord?.basal_energy_burned ?? null : null, "kcal")}
            {renderDeltaKpi(`${metricPrefix} Daylight`, isDaily ? getLatestNonNull('time_in_daylight') : avgRecord?.time_in_daylight ?? null, isDaily ? avgRecord?.time_in_daylight ?? null : null, "min")}
          </div>
        </Card>
      </section>

      {/* 🦶 Mobility & Gait  +  😴 Recovery & Environment */}
      <section className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <Card className="lg:col-span-3 p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <div className="w-7 h-7 rounded-[8px] bg-gradient-to-br from-[#B07850] to-[#8A5E3D] flex items-center justify-center">
              <Compass className="w-4 h-4 text-[#FAF6EF]" strokeWidth={2.5} />
            </div>
            <h3 className="text-[15px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Mobility & Gait</h3>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:gap-4 sm:grid-cols-3 lg:grid-cols-3">
            {renderDeltaKpi(`${metricPrefix} Walk Speed`, isDaily ? getLatestNonNull('walking_speed') : avgRecord?.walking_speed ?? null, isDaily ? avgRecord?.walking_speed ?? null : null, "km/h")}
            {renderDeltaKpi(`${metricPrefix} Steadiness`, isDaily ? getLatestNonNull('walking_steadiness') : avgRecord?.walking_steadiness ?? null, isDaily ? avgRecord?.walking_steadiness ?? null : null, "%")}
            {renderDeltaKpi(`${metricPrefix} Asymmetry`, isDaily ? getLatestNonNull('walking_asymmetry_pct') : avgRecord?.walking_asymmetry_pct ?? null, isDaily ? avgRecord?.walking_asymmetry_pct ?? null : null, "%")}
            {renderDeltaKpi(`${metricPrefix} Step Length`, isDaily ? getLatestNonNull('walking_step_length') : avgRecord?.walking_step_length ?? null, isDaily ? avgRecord?.walking_step_length ?? null : null, "m")}
            {renderDeltaKpi(`${metricPrefix} Dbl Support`, isDaily ? getLatestNonNull('walking_double_support_pct') : avgRecord?.walking_double_support_pct ?? null, isDaily ? avgRecord?.walking_double_support_pct ?? null : null, "%")}
            {renderDeltaKpi(`${metricPrefix} Stair Speed`, isDaily ? getLatestNonNull('stair_ascent_speed') : avgRecord?.stair_ascent_speed ?? null, isDaily ? avgRecord?.stair_ascent_speed ?? null : null, "m/s")}
          </div>
        </Card>

        <Card className="lg:col-span-2 p-5">
          <div className="flex items-center gap-2.5 mb-4">
            <div className="w-7 h-7 rounded-[8px] bg-gradient-to-br from-[#9b8b7e] to-[#7A6D62] flex items-center justify-center">
              <Battery className="w-4 h-4 text-[#FAF6EF]" strokeWidth={2.5} />
            </div>
            <h3 className="text-[15px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Recovery & Environment</h3>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:gap-4 sm:grid-cols-3">
            {renderDeltaKpi(`${metricPrefix} Sleep`, isDaily ? getLatestNonNull('total_sleep_hours') : avgRecord?.total_sleep_hours ?? null, isDaily ? avgRecord?.total_sleep_hours ?? null : null, "hrs")}
            {renderDeltaKpi(`${metricPrefix} Mindfulness`, isDaily ? getLatestNonNull('mindful_session_mins') : avgRecord?.mindful_session_mins ?? null, isDaily ? avgRecord?.mindful_session_mins ?? null : null, "min")}
            {renderDeltaKpi(`${metricPrefix} Audio Exp.`, isDaily ? getLatestNonNull('headphone_audio_exposure') : avgRecord?.headphone_audio_exposure ?? null, isDaily ? avgRecord?.headphone_audio_exposure ?? null : null, "dB")}
          </div>
        </Card>
      </section>

      {/* ════════ Unified Dashboard Grid ════════ */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* Correlation Engine — full width row */}
        {trendSeries.length > 0 && (
          <div className="lg:col-span-3">
            <section>
              <CorrelationEngine data={trendSeries} />
            </section>
          </div>
        )}

        {/* AI Nutrition Engine — full width row */}
        <div className="lg:col-span-3">
          {renderNutritionEngine()}
        </div>

        {/* Diabetes Management — hidden for now
        <div className="lg:col-span-1">
          {renderDiabetesManagement()}
        </div>
        */}

        {/* Health Insights — full width */}
        <div className="lg:col-span-3">
          {renderSignalIntelligence()}
        </div>
      </div>
    </div>
  )
}
