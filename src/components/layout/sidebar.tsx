"use client"

import { useState, useEffect } from "react"
import { 
  LayoutDashboard, 
  BarChart3, 
  HeartPulse, 
  Briefcase, 
  Megaphone
} from "lucide-react"
import { cn } from "../ui/cn"
import { LogoMark } from "../ui/logo"

const navItems = [
  { id: "overview", label: "Overview", icon: LayoutDashboard },
  { id: "data-science", label: "Data Science", icon: BarChart3 },
  { id: "well-being", label: "Well-Being", icon: HeartPulse },
  { id: "business", label: "Business", icon: Briefcase },
  { id: "marketing", label: "Marketing", icon: Megaphone },
]

interface SidebarProps {
  activeSpoke: string
  onNavigate: (spoke: string) => void
}

export function Sidebar({ activeSpoke, onNavigate }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false)

  return (
    <aside
      className={cn(
        "flex flex-col h-full bg-[var(--linen)] border-r border-[var(--border-subtle)] transition-all duration-300",
        collapsed ? "w-[60px]" : "w-[240px]"
      )}
    >
      {/* Logo */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-[var(--border-subtle)]">
        <div className="flex items-center gap-2">
          <LogoMark size={28} />
          {!collapsed && (
            <span
              className="text-[15px] italic text-[var(--deep-brown)]"
              style={{ fontFamily: "var(--font-display)" }}
            >
              Personal OS
            </span>
          )}
        </div>
        <button
          type="button"
          onClick={() => setCollapsed(!collapsed)}
          className="p-1 rounded hover:bg-[var(--soft-warm)] text-[var(--dust)] transition-colors"
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          <svg 
            width="16" 
            height="16" 
            viewBox="0 0 16 16" 
            fill="none"
            className={cn("transition-transform", collapsed ? "rotate-180" : "")}
          >
            <path 
              d="M10 12L6 8L10 4" 
              stroke="currentColor" 
              strokeWidth="1.5" 
              strokeLinecap="round" 
              strokeLinejoin="round"
            />
          </svg>
        </button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 px-3">
        {navItems.map((item) => {
          const Icon = item.icon
          const isActive = activeSpoke === item.id
          
          return (
            <button
              type="button"
              key={item.id}
              onClick={() => onNavigate(item.id)}
              className={cn(
                "touch-manipulation min-h-[44px]",
                "w-full flex items-center gap-3 px-3 py-2.5 mb-1 rounded-[12px] transition-all duration-200",
                "hover:bg-[var(--soft-warm)]",
                isActive ? "bg-[var(--warm-white)] shadow-[var(--shadow-sm)]" : "",
                collapsed ? "justify-center" : ""
              )}
            >
              <Icon className={cn("w-5 h-5", collapsed ? "w-6 h-6" : "")} style={{ color: isActive ? "var(--amber)" : "var(--dust)" }} />
              {!collapsed && (
                <span className={cn("text-[13px] font-light", isActive ? "text-[var(--deep-brown)]" : "text-[var(--mid-brown)]")}>
                  {item.label}
                </span>
              )}
            </button>
          )
        })}
      </nav>

      {/* System Status */}
      <div className="p-4">
        <div className="flex items-center gap-2">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[var(--sage)] opacity-40" />
            <span className="relative inline-flex rounded-full h-2 w-2 bg-[var(--sage)]" />
          </span>
          {!collapsed && <span className="text-[10px] uppercase tracking-[0.12em] text-[var(--dust)]">All quiet · synced</span>}
        </div>
      </div>
    </aside>
  )
}
