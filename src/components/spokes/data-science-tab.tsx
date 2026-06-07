"use client"

import { useEffect, useState } from "react"
import { Card } from "../ui/card"
import { KPIMetric } from "../ui/kpi-metric"
import { BarChart3 } from "lucide-react"

interface Project {
  project_name: string
  tier: string
  status: string
  start_date: string
  deployed_url: string
  github_url: string
  notes: string
  client_potential: string
}

export function DataScienceTab() {
  const [projects, setProjects] = useState<Project[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchProjects() {
      try {
        const response = await fetch('/api/data-science/tracker')
        const data = await response.json()
        setProjects(data.projects || [])
      } catch (error) {
        console.error('Failed to fetch projects:', error)
      } finally {
        setLoading(false)
      }
    }
    fetchProjects()
  }, [])

  const deployedCount = projects.filter(p => p.deployed_url && p.deployed_url !== '').length
  const inProgressCount = projects.filter(p => p.status === 'In Progress').length

  return (
    <div className="space-y-6">
      <section>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <KPIMetric label="Projects Deployed" value={deployedCount} />
          <KPIMetric label="In Progress" value={inProgressCount} />
        </div>
      </section>

      <section>
        <h2 className="text-[18px] font-semibold text-[var(--deep-brown)] mb-4" style={{ fontFamily: "var(--font-display)" }}>Project Tracker</h2>
        <Card>
          {loading ? (
            <div className="p-4 text-center text-[var(--dust)]">Loading projects...</div>
          ) : projects.length === 0 ? (
            <div className="p-4 text-center text-[var(--dust)]">No projects found. Add entries to your tracker to see them here.</div>
          ) : (
            <div className="space-y-2">
              {projects.map((project, index) => (
                <div key={index} className="flex items-center justify-between p-3 border-b border-[var(--border-subtle)] last:border-0 hover:bg-[var(--soft-warm)] transition-colors">
                  <div className="flex items-center gap-3">
                    <BarChart3 className="w-5 h-5 text-[var(--amber)]" />
                    <div>
                      <div className="text-[13px] text-[var(--deep-brown)] font-medium">{project.project_name}</div>
                      <div className="text-[11px] text-[var(--dust)]">{project.tier}</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="px-2 py-1 rounded-full text-[11px]"
                      style={{
                        backgroundColor: project.status === 'Deployed' ? 'var(--sage-low)' : project.status === 'In Progress' ? 'var(--amber-low)' : 'transparent',
                        color: project.status === 'Deployed' ? 'var(--sage)' : project.status === 'In Progress' ? 'var(--amber)' : 'var(--dust)',
                        border: `1px solid ${project.status === 'Deployed' ? 'var(--sage-low)' : project.status === 'In Progress' ? 'var(--amber-low)' : 'var(--border-subtle)'}`,
                      }}
                    >
                      {project.status}
                    </span>
                    <span className="text-[11px] text-[var(--dust)]">{project.start_date}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>
      </section>
    </div>
  )
}
