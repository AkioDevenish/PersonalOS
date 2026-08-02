"use client"

import Link from "next/link"
import { ArrowRight } from "lucide-react"
import { useAuth } from "@clerk/nextjs"
import s from "./marketing.module.css"
import sh from "../shared.module.css"

/**
 * Closing call to action. Resolves its own destination from auth state so
 * pages can stay server components.
 */
export default function CtaBand({
  title,
  label = "Open your ledger",
}: {
  title: React.ReactNode
  label?: string
}) {
  const { isSignedIn } = useAuth()

  return (
    <section className={s.ctaBand}>
      <h2 className={s.ctaBandTitle}>{title}</h2>
      <Link href="/download" className={sh.cta}>
        {label} <ArrowRight size={15} />
      </Link>
    </section>
  )
}
