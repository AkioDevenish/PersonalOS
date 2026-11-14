import type { Metadata } from "next"
import { Pitchfork } from "./pitchfork"

export const metadata: Metadata = { title: "Pitchfork · Forklore" }

export default function PitchforkPage() {
  return <Pitchfork />
}
