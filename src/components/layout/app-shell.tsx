"use client"

import { useState } from "react"
import { Sidebar } from "./sidebar"
import { Header } from "./header"
import { Menu } from "lucide-react"

interface AppShellProps {
  children: React.ReactNode
  activeSpoke: string
  onNavigate: (spoke: string) => void
}

export function AppShell({ children, activeSpoke, onNavigate }: AppShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false)

  return (
    <div className="flex h-[100dvh] bg-[var(--linen)] overflow-hidden">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/20 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar — hidden on mobile, slide-in drawer on tablet, always visible on desktop */}
      <div className={`
        fixed inset-y-0 left-0 z-50 lg:relative lg:z-auto
        transition-transform duration-300 ease-out
        ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
      `}>
        <Sidebar
          activeSpoke={activeSpoke}
          onNavigate={(spoke) => {
            onNavigate(spoke)
            setSidebarOpen(false)
          }}
        />
      </div>

      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        <Header onMenuToggle={() => setSidebarOpen(!sidebarOpen)} />

        <main className="flex-1 overflow-y-auto p-4 sm:p-6 md:p-8 lg:p-10">
          <div className="max-w-[1800px] mx-auto">
            {children}
          </div>
        </main>
      </div>
    </div>
  )
}
