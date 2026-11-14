import type { Metadata } from "next"
import { Profile } from "./profile"

export const metadata: Metadata = { title: "Experts · Forklore" }

export default function SpecialistPage() {
  return <Profile />
}
