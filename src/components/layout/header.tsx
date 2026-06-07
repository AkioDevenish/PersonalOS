"use client"

import { useState, useEffect } from "react"
import { Search, Menu } from "lucide-react"
import { UserButton } from '@clerk/nextjs'

interface HeaderProps {
  onMenuToggle?: () => void
}

export function Header({ onMenuToggle }: HeaderProps) {
  const [stateOfMind, setStateOfMind] = useState<string | null>(null)

  useEffect(() => {
    async function fetchStateOfMind() {
      try {
        const res = await fetch("/api/well-being/telemetry")
        const data = await res.json()
        if (data.success && data.events && data.events.length > 0) {
          const somEvent = data.events.find((e: any) => e.category === 'State of Mind')
          if (somEvent && somEvent.notes) {
            // Take just the first label if it's a long comma-separated list to save space
            const firstLabel = somEvent.notes.split(',')[0].trim()
            setStateOfMind(firstLabel)
          }
        }
      } catch (err) {
        console.error("Failed to fetch state of mind", err)
      }
    }
    fetchStateOfMind()
  }, [])

  return (
    <header className="h-14 bg-[var(--linen)] flex items-center justify-between px-4 sm:px-6 border-b border-[var(--border-subtle)]">
      {/* Left side — hamburger on mobile */}
      <div className="flex items-center gap-3">
        {onMenuToggle && (
          <button
            type="button"
            onClick={onMenuToggle}
            className="p-2 rounded-[8px] hover:bg-[var(--soft-warm)] text-[var(--dust)] transition-colors lg:hidden"
            aria-label="Toggle navigation"
          >
            <Menu className="w-5 h-5" />
          </button>
        )}
      </div>

      {/* Right side */}
      <div className="flex items-center gap-2 sm:gap-4">
        {stateOfMind && (
          <div className="hidden sm:flex items-center gap-2 mr-2 sm:mr-4">
            <span className="hidden md:inline text-[12px] uppercase tracking-widest text-[var(--dust)] font-medium">State of Mind</span>
            <span className="px-3 sm:px-4 py-1.5 rounded-full bg-[var(--sage)]/10 border border-[var(--sage)]/20 shadow-[var(--shadow-sm)] text-[12px] sm:text-[14px] font-medium text-[var(--deep-brown)] whitespace-nowrap capitalize">
              ✨ {stateOfMind}
            </span>
          </div>
        )}
        <div className="flex items-center gap-2 sm:gap-3 border-l border-[var(--border-subtle)] pl-3 sm:pl-4">
          <button className="p-2 rounded-[8px] hover:bg-[var(--soft-warm)] text-[var(--dust)] transition-colors">
            <Search className="w-4 h-4" />
          </button>
          <UserButton 
            appearance={{
              elements: {
                avatarBox: 'w-8 h-8',
                userButtonPopoverCard: 'shadow-md',
                userButtonPopoverActionButton: 'hover:bg-[var(--soft-warm)]',
              }
            }}
            afterSignOutUrl="/"
          />
        </div>
      </div>
    </header>
  )
}
