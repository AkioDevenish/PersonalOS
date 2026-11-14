import type { Metadata } from "next"
import localFont from "next/font/local"
import "./app.css"
import { Providers } from "./providers"
import { Shell } from "./shell"

/** The web version of Forklore: the same account and backend as the iOS app. */

const serif = localFont({
  src: [
    { path: "../../../ios/Forklore/Fonts/EBGaramond.ttf", style: "normal", weight: "400 800" },
    { path: "../../../ios/Forklore/Fonts/EBGaramond-Italic.ttf", style: "italic", weight: "400 800" },
  ],
  variable: "--fl-serif",
  display: "swap",
})

const sans = localFont({
  src: [
    { path: "../../../ios/Forklore/Fonts/Jost-Regular.ttf", weight: "400" },
    { path: "../../../ios/Forklore/Fonts/Jost-Medium.ttf", weight: "500" },
  ],
  variable: "--fl-sans",
  display: "swap",
})

export const metadata: Metadata = {
  title: "Forklore",
  description: "What to eat next, with Pitchfork and real nutritionists.",
}

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className={`fl ${serif.variable} ${sans.variable}`}>
      <Providers>
        <Shell>{children}</Shell>
      </Providers>
    </div>
  )
}
