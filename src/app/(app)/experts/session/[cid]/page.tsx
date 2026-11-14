import type { Metadata } from "next"
import { Session } from "./session"

export const metadata: Metadata = { title: "Consultation · Forklore" }

export default function SessionPage() {
  return <Session />
}
