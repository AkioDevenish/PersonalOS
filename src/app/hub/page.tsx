"use client"

import { useState } from "react"
import { AppShell } from "@/components/layout/app-shell"
import { OverviewTab } from "@/components/overview/overview-tab"
import { DataScienceTab } from "@/components/spokes/data-science-tab"
import { WellBeingTab } from "@/components/spokes/well-being-tab"
import { BusinessTab } from "@/components/spokes/business-tab"
import { MarketingTab } from "@/components/spokes/marketing-tab"

export default function Home() {
  const [activeSpoke, setActiveSpoke] = useState("overview")

  const renderContent = () => {
    switch (activeSpoke) {
      case "overview":
        return <OverviewTab />
      case "data-science":
        return <DataScienceTab />
      case "well-being":
        return <WellBeingTab />
      case "business":
        return <BusinessTab />
      case "marketing":
        return <MarketingTab />
      default:
        return <OverviewTab />
    }
  }

  return (
    <AppShell activeSpoke={activeSpoke} onNavigate={setActiveSpoke}>
      {renderContent()}
    </AppShell>
  )
}
