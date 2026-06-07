import { cn } from "./cn"
import { ReactNode } from "react"

interface CardProps {
  children: ReactNode
  className?: string
  variant?: "default" | "active" | "sage" | "soft"
}

export function Card({ children, className, variant = "default" }: CardProps) {
  const variantStyles = {
    default: "bg-[var(--warm-white)] border border-[var(--border-subtle)]",
    active: "bg-[var(--warm-white)] border border-[var(--border-subtle)]",
    sage: "bg-[var(--sage-low)] border border-[rgba(125,147,122,0.15)]",
    soft: "bg-[var(--soft-warm)] border border-[var(--border-subtle)]",
  }

  return (
    <div
      className={cn(
        "rounded-[14px] p-6 transition-all duration-300 overflow-hidden",
        "hover:border-[var(--border-mid)]",
        variantStyles[variant],
        className
      )}
    >
      {children}
    </div>
  )
}
