import type { Metadata } from "next"
import { Read } from "./read"

export const metadata: Metadata = { title: "Read · Forklore" }

export default function ReadPage() {
  return <Read />
}
