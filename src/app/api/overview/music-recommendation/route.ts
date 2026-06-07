import { NextResponse } from 'next/server'
import Database from 'better-sqlite3'
import path from 'path'
import os from 'os'

const dbPath = path.join(os.homedir(), 'personal_os', 'Well Being', 'data', 'health.db')
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate'
const OLLAMA_MODEL = process.env.GEMMA_MODEL || process.env.OLLAMA_MODEL || 'gemma4'
const FALLBACK = {
  artist: 'Tycho',
  track: 'Awake',
  genre: 'Ambient',
  reason: 'A calm fallback while Ollama is unavailable.',
}

async function runOllama(prompt: string): Promise<string> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 30_000)
  try {
    const response = await fetch(OLLAMA_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: OLLAMA_MODEL, prompt, stream: false }),
      signal: controller.signal,
    })
    if (!response.ok) {
      throw new Error(`Ollama HTTP ${response.status}`)
    }
    const data = await response.json()
    const text = typeof data.response === 'string' ? data.response.trim() : ''
    if (!text) throw new Error('Empty Ollama response')
    return text
  } finally {
    clearTimeout(timeout)
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json().catch(() => ({}))
    const { timeOfDay, dayName } = body

    // 1. Fetch today's health data from SQLite
    let todayHealth = ''
    try {
      const db = new Database(dbPath)
      const rows = db.prepare(`
        SELECT metric_type, MAX(value) as value
        FROM health_metrics
        WHERE date >= date('now', 'localtime')
        GROUP BY metric_type
      `).all() as any[]
      db.close()

      if (rows && rows.length > 0) {
        todayHealth = rows.map(r => `${r.metric_type}: ${r.value}`).join(', ')
      }
    } catch (e) {
      console.error('Failed to query health db for music rec:', e)
    }

    // 2. Build Prompt
    const prompt = `You are an expert Music Curator. It is currently ${timeOfDay || 'Unknown'} on ${dayName || 'Unknown'}.
The user has the following health and physiological telemetry for today:
${todayHealth || 'No physical data available.'}

Based purely on this physical data (e.g., if they have high steps/energy, recommend recovery or high-energy music; if low sleep, recommend relaxing music), recommend exactly ONE song. 

Output ONLY a raw JSON object with no markdown formatting or backticks. Format:
{
  "artist": "Artist Name",
  "track": "Track Name",
  "genre": "Genre",
  "reason": "1 short sentence explaining why this matches their physical telemetry today."
}`

    // 3. Ask Ollama
    const llmResponse = await runOllama(prompt)
    let recommendation: any
    try {
      // Strip any accidental markdown blocks that the LLM might have included
      const cleaned = llmResponse.replace(/```json/g, '').replace(/```/g, '').trim()
      recommendation = JSON.parse(cleaned)
    } catch (e) {
      console.error('Failed to parse Ollama JSON:', llmResponse)
      recommendation = FALLBACK
    }

    // Try to get an iTunes preview URL and a YouTube full video ID
    try {
      const term = encodeURIComponent(`${recommendation.artist} ${recommendation.track}`)
      const itunesRes = await fetch(`https://itunes.apple.com/search?term=${term}&entity=song&limit=1`)
      const itunesData = await itunesRes.json()
      if (itunesData.results && itunesData.results.length > 0) {
        recommendation.previewUrl = itunesData.results[0].previewUrl
        recommendation.artworkUrl = itunesData.results[0].artworkUrl100
      }

      // Scrape YouTube for full video ID
      const ytRes = await fetch(`https://www.youtube.com/results?search_query=${term}`)
      const ytHtml = await ytRes.text()
      const ytMatch = ytHtml.match(/"videoId":"([^"]{11})"/)
      if (ytMatch && ytMatch[1]) {
        recommendation.youtubeId = ytMatch[1]
      }
    } catch (e) {
      console.error('Fetch failed:', e)
    }

    return NextResponse.json(recommendation)
  } catch (error) {
    console.error('Music recommendation failed:', error)
    return NextResponse.json(FALLBACK, { status: 200 })
  }
}
