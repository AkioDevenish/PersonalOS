import type { Metadata } from "next"
import { Experts } from "./experts"

export const metadata: Metadata = { title: "Experts · Forklore" }

export default function ExpertsPage() {
  return <Experts />
}
