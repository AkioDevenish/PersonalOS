"use client"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { useState } from "react"
import { useConvexAuth, useQuery } from "convex/react"
import { api } from "../../../convex/_generated/api"
import { Icon, PAGES } from "./nav"
import { SignIn } from "./signin"

/**
 * Everything around a page: the sign-in gate, then the sidebar. On a wide window the sidebar
 * stays out; on a phone-sized one it slides in from the menu button, as in the iOS app.
 */
export function Shell({ children }: { children: React.ReactNode }) {
  const { isLoading, isAuthenticated } = useConvexAuth()

  if (isLoading) return <Splash />
  if (!isAuthenticated) return <SignIn />
  return <Signed>{children}</Signed>
}

function Splash() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <span className="fl-serif text-3xl opacity-60">Forklore</span>
    </div>
  )
}

function Signed({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false)
  const path = usePathname()

  return (
    <div className="lg:flex">
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-[272px] border-r border-[var(--fl-line)] bg-[var(--fl-bg)] px-4 pb-6 pt-5 transition-transform duration-300 lg:sticky lg:top-0 lg:h-dvh lg:translate-x-0 ${
          open ? "translate-x-0 shadow-2xl" : "-translate-x-full"
        }`}
        aria-label="Pages"
      >
        <Sidebar path={path} onPick={() => setOpen(false)} />
      </aside>
      {open && (
        <button
          className="fixed inset-0 z-30 bg-black/20 lg:hidden"
          aria-label="Close menu"
          onClick={() => setOpen(false)}
        />
      )}

      <div className="min-w-0 flex-1">
        <div className="sticky top-0 z-20 flex items-center px-4 pt-3 lg:hidden">
          <button
            className="flex h-11 w-11 items-center justify-center rounded-full border border-[var(--fl-line)] bg-[var(--fl-raised)] shadow-[var(--fl-shadow)] backdrop-blur"
            aria-label="Menu"
            onClick={() => setOpen(true)}
          >
            <Icon name="menu" />
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}

function Sidebar({ path, onPick }: { path: string; onPick: () => void }) {
  const me = useQuery(api.users.me)
  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center justify-between px-3 pb-6">
        <Link href="/pitchfork" onClick={onPick} className="fl-serif text-[28px] tracking-tight">
          Forklore
        </Link>
        <button className="lg:hidden" aria-label="Close menu" onClick={onPick}>
          <Icon name="close" />
        </button>
      </div>
      <nav className="flex flex-col gap-1">
        {PAGES.map((p) => (
          <Link
            key={p.href}
            href={p.href}
            onClick={onPick}
            className="fl-nav-item"
            aria-current={path.startsWith(p.href) ? "page" : undefined}
          >
            <Icon name={p.icon} />
            {p.title}
          </Link>
        ))}
      </nav>
      <div className="mt-auto px-3">
        <p className="fl-kicker">Signed in</p>
        <p className="mt-1 truncate text-sm text-[var(--fl-text-2)]">{me?.name || me?.email || " "}</p>
      </div>
    </div>
  )
}

/** The column every page sits in. */
export function Page({ children, wide = false }: { children: React.ReactNode; wide?: boolean }) {
  return (
    <main className={`mx-auto w-full px-5 pb-20 pt-4 lg:pt-12 ${wide ? "max-w-4xl" : "max-w-2xl"}`}>{children}</main>
  )
}

/** A page's opening: kicker, title, a line under it. */
export function Header({ kicker, title, lede }: { kicker: string; title: string; lede?: string }) {
  return (
    <header className="fl-in">
      <p className="fl-kicker accent">{kicker}</p>
      <h1 className="fl-title mt-2">{title}</h1>
      {lede && <p className="fl-lede mt-3">{lede}</p>}
    </header>
  )
}
