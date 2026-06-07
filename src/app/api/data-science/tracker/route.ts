import { NextResponse } from 'next/server'
import fs from 'fs'
import path from 'path'

const TRACKER_PATH = path.join(process.env.HOME || '', 'personal_os/Data Science/data_science/tracker.csv')

export async function GET() {
  try {
    if (!fs.existsSync(TRACKER_PATH)) {
      return NextResponse.json({ projects: [] })
    }

    const content = fs.readFileSync(TRACKER_PATH, 'utf-8')
    const lines = content.split('\n').filter(line => line.trim())
    
    if (lines.length < 2) {
      return NextResponse.json({ projects: [] })
    }

    const headers = lines[0].split(',')
    const projects = lines.slice(1).map(line => {
      const values = line.split(',')
      const project: Record<string, string> = {}
      headers.forEach((header, index) => {
        project[header.trim()] = values[index]?.trim() || ''
      })
      return project
    }).filter(p => p.project_name)

    return NextResponse.json({ projects })
  } catch (error) {
    console.error('Error reading tracker.csv:', error)
    return NextResponse.json({ error: 'Failed to read tracker data' }, { status: 500 })
  }
}
