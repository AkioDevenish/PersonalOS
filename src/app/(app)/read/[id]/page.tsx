import type { Metadata } from "next"
import { Reader } from "./reader"

export const metadata: Metadata = { title: "Read · Forklore" }

export default function ArticlePage() {
  return <Reader />
}
