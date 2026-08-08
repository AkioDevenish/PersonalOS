import { NextResponse } from 'next/server'
import Database from 'better-sqlite3'
import path from 'path'
import os from 'os'
import { generateForUser, readSettings, requireCaller } from '@/lib/ai/user-model'

const dbPath = process.env.HEALTH_DB_PATH || path.join(os.homedir(), 'personal_os', 'Well Being', 'data', 'health.db')
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate'
const OLLAMA_MODEL = process.env.GEMMA_MODEL || process.env.OLLAMA_MODEL || 'gemma4'

function ensureNutritionTable(db: ReturnType<typeof Database>) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS nutrition_recommendations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meal_context TEXT NOT NULL,
      recommendation_text TEXT NOT NULL,
      meal_names TEXT,
      insight TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `)
}

function getRecentRecommendations(db: ReturnType<typeof Database>, limit = 5): string[] {
  ensureNutritionTable(db)
  const rows = db.prepare(`
    SELECT meal_names FROM nutrition_recommendations
    WHERE meal_names IS NOT NULL AND meal_names != ''
    ORDER BY created_at DESC LIMIT ?
  `).all(limit) as { meal_names: string }[]
  return rows.map(r => r.meal_names).filter(Boolean)
}

function saveRecommendation(db: ReturnType<typeof Database>, context: string, text: string) {
  ensureNutritionTable(db)
  // Extract meal names from the text for dedup
  const nameMatches = text.match(/\*\*Name:\*\*\s*(.+)/g) || []
  const mealNames = nameMatches.map(m => m.replace('**Name:**', '').trim()).join(', ')
  const insightMatch = text.match(/\[NUTRITION_INSIGHT\]\s*(.+)/)
  const insight = insightMatch?.[1]?.trim() || null

  db.prepare(`
    INSERT INTO nutrition_recommendations (meal_context, recommendation_text, meal_names, insight)
    VALUES (?, ?, ?, ?)
  `).run(context, text, mealNames, insight)
}

export async function POST(request: Request) {
  try {
    const body = await request.json().catch(() => ({}))
    const userQuery = body.query || ''
    const mealContext = body.context || '' // e.g. "breakfast", "pre-workout", "snack"
    /**
     * Where the person cooks and shops.
     *
     * Without it the model reaches for the same handful of Californian
     * wellness food every time, and a meal you can't buy the ingredients for
     * is not a recommendation. Sent as a display name rather than a code so
     * the prompt reads as English.
     */
    const country = typeof body.country === 'string' ? body.country.trim() : ''

    const db = new Database(dbPath)

    // Get today's metabolic events
    const today = new Date().toISOString().split('T')[0]
    const events = db.prepare(`
      SELECT timestamp, category, intensity, notes 
      FROM metabolic_events 
      WHERE date(timestamp) = ?
      ORDER BY timestamp DESC
    `).all(today) as any[]

    // Get recent health metrics (last 3 days — daily detail)
    const healthRows = db.prepare(`
      WITH Pivoted AS (
        SELECT
          date,
          MAX(CASE WHEN metric_type = 'steps' THEN value END) as steps,
          MAX(CASE WHEN metric_type = 'active_energy_burned' THEN value END) as active_energy_burned,
          MAX(CASE WHEN metric_type = 'basal_energy_burned' THEN value END) as basal_energy_burned,
          MAX(CASE WHEN metric_type = 'total_sleep_hours' THEN value END) as total_sleep_hours,
          ROUND(AVG(CASE WHEN metric_type = 'blood_glucose_mgdl' THEN value END), 1) as avg_blood_glucose_mgdl,
          MAX(CASE WHEN metric_type = 'dietary_carbohydrates_g' THEN value END) as dietary_carbohydrates_g,
          MAX(CASE WHEN metric_type = 'insulin_delivery_iu' THEN value END) as insulin_delivery_iu,
          MAX(CASE WHEN metric_type = 'distance_km' THEN value END) as distance_km
        FROM health_metrics
        WHERE source_file IN ('healthkit', 'daily_health.txt')
          AND date >= date('now', '-3 days')
        GROUP BY date, source_file
      )
      SELECT * FROM Pivoted ORDER BY date DESC LIMIT 5
    `).all() as any[]

    // 7-day rolling averages
    const weeklyAvg = db.prepare(`
      SELECT
        ROUND(AVG(CASE WHEN metric_type = 'steps' THEN value END)) as avg_steps,
        ROUND(AVG(CASE WHEN metric_type = 'active_energy_burned' THEN value END)) as avg_active_cal,
        ROUND(AVG(CASE WHEN metric_type = 'total_sleep_hours' THEN value END), 1) as avg_sleep_hrs,
        ROUND(AVG(CASE WHEN metric_type = 'blood_glucose_mgdl' THEN value END), 1) as avg_glucose,
        ROUND(AVG(CASE WHEN metric_type = 'dietary_carbohydrates_g' THEN value END)) as avg_carbs_g,
        ROUND(AVG(CASE WHEN metric_type = 'distance_km' THEN value END), 1) as avg_distance_km
      FROM health_metrics
      WHERE source_file IN ('healthkit', 'daily_health.txt')
        AND date >= date('now', '-7 days')
    `).get() as any

    // 30-day rolling averages
    const monthlyAvg = db.prepare(`
      SELECT
        ROUND(AVG(CASE WHEN metric_type = 'steps' THEN value END)) as avg_steps,
        ROUND(AVG(CASE WHEN metric_type = 'active_energy_burned' THEN value END)) as avg_active_cal,
        ROUND(AVG(CASE WHEN metric_type = 'total_sleep_hours' THEN value END), 1) as avg_sleep_hrs,
        ROUND(AVG(CASE WHEN metric_type = 'blood_glucose_mgdl' THEN value END), 1) as avg_glucose,
        ROUND(AVG(CASE WHEN metric_type = 'dietary_carbohydrates_g' THEN value END)) as avg_carbs_g,
        ROUND(AVG(CASE WHEN metric_type = 'distance_km' THEN value END), 1) as avg_distance_km
      FROM health_metrics
      WHERE source_file IN ('healthkit', 'daily_health.txt')
        AND date >= date('now', '-30 days')
    `).get() as any

    // Get recent state of mind
    let stateOfMind = ''
    try {
      const som = db.prepare(`
        SELECT labels, valence FROM state_of_mind_entries
        ORDER BY timestamp DESC LIMIT 1
      `).get() as any
      if (som) {
        stateOfMind = `\nCONTEXT — Current State of Mind: ${som.labels}${som.valence != null ? ` (valence: ${som.valence})` : ''}`
      }
    } catch (_) { /* table may not exist */ }

    // Get previous recommendations to avoid repeating
    const recentRecs = getRecentRecommendations(db, 5)

    db.close()

    const eventsContext = events.length > 0
      ? events.map(e => `  ${e.timestamp}: ${e.category}${e.intensity ? ` (${e.intensity})` : ''}${e.notes ? ` — ${e.notes}` : ''}`).join('\n')
      : '  No metabolic events logged today.'

    const healthContext = healthRows.length > 0
      ? JSON.stringify(healthRows, null, 2)
      : '  No recent health data available.'

    const weeklyContext = weeklyAvg ? JSON.stringify(weeklyAvg, null, 2) : '  No 7-day data.'
    const monthlyContext = monthlyAvg ? JSON.stringify(monthlyAvg, null, 2) : '  No 30-day data.'

    // Build the current time and day context
    const now = new Date()
    const timeStr = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })
    const dayStr = now.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
    const hour = now.getHours()

    let mealTiming = ''
    if (mealContext) {
      mealTiming = `The user has specifically requested: ${mealContext} recommendations.`
    } else if (hour < 10) {
      mealTiming = 'It is morning — recommend breakfast or a morning snack.'
    } else if (hour < 12) {
      mealTiming = 'It is late morning — recommend a mid-morning snack or early lunch.'
    } else if (hour < 14) {
      mealTiming = 'It is lunchtime — recommend a full lunch.'
    } else if (hour < 17) {
      mealTiming = 'It is afternoon — recommend an afternoon snack or light meal.'
    } else if (hour < 20) {
      mealTiming = 'It is evening — recommend dinner.'
    } else {
      mealTiming = 'It is late evening — recommend a light snack or sleep-promoting food.'
    }

    const avoidSection = recentRecs.length > 0
      ? `\nCRITICAL — DO NOT RECOMMEND THESE (recently suggested):\n${recentRecs.map(r => `  - ${r}`).join('\n')}\nYou MUST suggest completely different meals/foods from the above list. Be creative and diverse.`
      : ''

    const prompt = `You are a Senior Sports Nutritionist & Diabetic Meal Planning Specialist. You have deep expertise in glycemic index optimization, macronutrient timing, and performance nutrition. You are creative and never repeat yourself.

CURRENT TIME: ${timeStr} on ${dayStr}
MEAL TIMING: ${mealTiming}${country ? `
WHERE THEY EAT: ${country}. Every recommendation must be a dish eaten in ${country}, built from ingredients ordinarily sold there. Use the local name for the dish where it has one. Do not recommend anything that would have to be imported or specially ordered.` : ''}

CONTEXT — Today's Metabolic Events:
${eventsContext}

CONTEXT — Recent Health Telemetry (last 3 days, daily detail):
${healthContext}

CONTEXT — 7-Day Rolling Averages:
${weeklyContext}

CONTEXT — 30-Day Rolling Averages:
${monthlyContext}
${stateOfMind}
${avoidSection}

${userQuery ? `USER QUESTION: ${userQuery}\n` : ''}
Based on ALL of the above data, provide exactly 3 meal/snack recommendations optimized for this user's current metabolic state. Use the 7-day and 30-day trends to identify patterns (e.g., chronically low sleep, rising glucose, declining activity) and factor those into your recommendations.

RULES:
- If the user is in a fasting state, recommend foods to break the fast optimally.
- If blood glucose is elevated or they had a high glycemic load, recommend LOW glycemic options.
- If they had a caffeine spike, recommend foods that buffer cortisol.
- If they had high cognitive load, recommend brain-fuel foods (omega-3, complex carbs).
- If they logged high physical activity, recommend recovery nutrition.
- If they are diabetic (insulin_delivery_iu present), ALWAYS prioritize blood sugar stability.
- If 30-day avg glucose is trending higher than 7-day, note the improvement or call out the regression.
- If sleep is chronically low (< 7hrs avg over 30 days), recommend sleep-promoting nutrients.
- Account for the time of day when recommending meals vs snacks.
- Be CREATIVE and DIVERSE${country ? ` within the food of ${country} — vary the dish, the protein and the method, not the country` : '. Use foods from various cuisines'}.
- Consider foods that are seasonal and practical${country ? ` in ${country}` : ''}.

FORMAT each recommendation exactly like this:
[MEAL_REC]
**Name:** <Meal/Snack Name>
**Why:** <1-sentence reason tied to their specific data>
**Macros:** <Approx calories | protein | carbs | fat>
**GI Score:** <Low/Medium/High>
**Prep:** <Simple 1-2 sentence prep instructions>

After the 3 recommendations, add one line:
[NUTRITION_INSIGHT] <A single-sentence metabolic insight about their current nutritional state based on the data>

No greetings. No disclaimers. No markdown headers. Just the structured output.`

    /**
     * A user who picked a hosted model gets it here.
     *
     * Only the local Ollama path streams. The hosted providers each have their
     * own streaming protocol, and the app doesn't consume this incrementally
     * anyway — it reads the whole body before rendering — so a single
     * non-streaming call buys nothing but simplicity. The response shape and
     * content type stay identical either way, so the client can't tell.
     */
    const caller = await requireCaller(request).catch(() => null)
    const selection = caller ? (await readSettings(caller)).selection : null

    if (caller && selection && selection.provider !== 'ollama') {
      const { text } = await generateForUser(caller, prompt, { temperature: 1.0 })
      const db = new Database(dbPath)
      try {
        saveRecommendation(db, mealContext || mealTiming, text)
      } finally {
        db.close()
      }
      return new Response(text, {
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      })
    }

    const ollamaRes = await fetch(OLLAMA_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        prompt,
        stream: true,
        options: {
          temperature: 1.0,
          top_k: 60,
          top_p: 0.92,
        },
      }),
    })

    if (!ollamaRes.ok) {
      const errText = await ollamaRes.text()
      throw new Error(`Ollama error ${ollamaRes.status}: ${errText.slice(0, 300)}`)
    }

    // Collect full text so we can save it after streaming
    let fullText = ''
    const dbForSave = new Database(dbPath)

    const stream = new ReadableStream({
      async start(controller) {
        const reader = ollamaRes.body?.getReader()
        if (!reader) {
          controller.close()
          return
        }
        const decoder = new TextDecoder()
        const encoder = new TextEncoder()
        
        try {
          while (true) {
            const { done, value } = await reader.read()
            if (done) break
            const chunk = decoder.decode(value, { stream: true })
            const lines = chunk.split('\n').filter(Boolean)
            for (const line of lines) {
              try {
                const data = JSON.parse(line)
                if (data.response) {
                  fullText += data.response
                  controller.enqueue(encoder.encode(data.response))
                }
              } catch (e) {
                // Ignore incomplete JSON chunks, handled natively by Ollama's NDJSON
              }
            }
          }
        } finally {
          reader.releaseLock()
          controller.close()
          // Save the recommendation to history
          try {
            saveRecommendation(dbForSave, mealContext || mealTiming, fullText)
          } catch (e) {
            console.error('Failed to save nutrition recommendation:', e)
          } finally {
            dbForSave.close()
          }
        }
      }
    })

    return new Response(stream, {
      headers: { 'Content-Type': 'text/plain; charset=utf-8' }
    })
  } catch (error: any) {
    console.error('Nutrition AI error:', error)
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}

// GET: Return recent recommendation history
export async function GET() {
  try {
    const db = new Database(dbPath)
    ensureNutritionTable(db)
    const rows = db.prepare(`
      SELECT id, meal_context, meal_names, insight, created_at
      FROM nutrition_recommendations
      ORDER BY created_at DESC
      LIMIT 15
    `).all()
    db.close()
    return NextResponse.json({ success: true, history: rows })
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  try {
    const { id } = await request.json()
    if (!id) {
      return NextResponse.json({ success: false, error: 'ID is required' }, { status: 400 })
    }
    const db = new Database(dbPath)
    db.prepare('DELETE FROM nutrition_recommendations WHERE id = ?').run(id)
    db.close()
    return NextResponse.json({ success: true })
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 })
  }
}
