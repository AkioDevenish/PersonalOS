import { NextResponse } from 'next/server'
import Database from 'better-sqlite3'
import path from 'path'

const DB_PATH = path.join(process.env.HOME || '', 'personal_os/Market/data/marketing.db')

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { bullets, platform, topic, mood } = body

    if (!bullets || !platform) {
      return NextResponse.json({ error: 'bullets and platform are required' }, { status: 400 })
    }

    // Build prompt for Ollama
    const bulletList = Array.isArray(bullets) ? bullets : bullets.split('\n').filter((b: string) => b.trim())
    const prompt = `Write a ${mood || 'educational'} ${platform} post about ${topic || 'data science'}.

Here are the key points:
${bulletList.map((b: string) => `- ${b}`).join('\n')}

Write the actual post content (not bullet points). Make it engaging and native to ${platform}. Keep it concise.

Post:`

    // Call Ollama
    const ollamaRes = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'llama3.2',
        prompt,
        stream: false,
      }),
    })

    if (!ollamaRes.ok) {
      return NextResponse.json({ error: 'Ollama not responding. Is it running?' }, { status: 503 })
    }

    const ollamaData = await ollamaRes.json()
    const content = ollamaData.response?.trim() || 'No content generated.'

    // Save to database
    const db = new Database(DB_PATH)
    const stmt = db.prepare(`
      INSERT INTO posts (bullets, platform, topic, mood, content, published)
      VALUES (?, ?, ?, ?, ?, 0)
    `)
    const result = stmt.run(
      JSON.stringify(bulletList),
      platform,
      topic || null,
      mood || null,
      content
    )
    db.close()

    return NextResponse.json({
      id: result.lastInsertRowid,
      content,
      platform,
      topic,
      mood,
    })
  } catch (error) {
    console.error('Error generating post:', error)
    return NextResponse.json({ error: 'Failed to generate post' }, { status: 500 })
  }
}
