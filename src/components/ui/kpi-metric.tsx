import { cn } from "./cn"
import { TrendingUp, TrendingDown } from "lucide-react"

interface KPIMetricProps {
  label: string
  value: string | number
  trend?: number
  trendLabel?: string
  className?: string
}

export function KPIMetric({ label, value, trend, trendLabel, className }: KPIMetricProps) {
  const isPositive = trend !== undefined && trend >= 0
  const trendIcon = trend !== undefined ? (isPositive ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />) : null
  const trendColor = trend !== undefined
    ? (isPositive ? "text-[var(--sage)]" : "text-[var(--accent-danger)]")
    : "text-[var(--dust)]"

  return (
    <div className={cn("flex flex-col gap-1", className)}>
      <span className="text-[10px] uppercase text-[var(--dust)] font-medium tracking-[0.1em]">
        {label}
      </span>
      <div className="flex items-baseline gap-2">
        <span className="text-[22px] font-light text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>
          {value}
        </span>
        {trend !== undefined && (
          <span className={cn("flex items-center gap-1 text-xs font-light", trendColor)}>
            {trendIcon}
            {Math.abs(trend)}
          </span>
        )}
      </div>
      {trendLabel && (
        <span className="text-[12px] text-[var(--dust)] font-light">
          {trendLabel}
        </span>
      )}
    </div>
  )
}
