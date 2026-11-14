import { redirect } from "next/navigation"

/** The app opens on Pitchfork, as on the phone. */
export default function Home() {
  redirect("/pitchfork")
}
