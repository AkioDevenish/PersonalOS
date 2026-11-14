import type { Metadata } from "next"
import { Profile } from "./profile"

export const metadata: Metadata = { title: "Profile · Forklore" }

export default function ProfilePage() {
  return <Profile />
}
