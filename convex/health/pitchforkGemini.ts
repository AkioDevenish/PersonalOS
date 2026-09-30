/**
 * Pitchfork on Google's Gemini API, for testing on the dev deployment with Gemini's free tier.
 *
 * Google may use what the free tier receives to improve its models, and the privacy page only
 * names Anthropic, so this must never answer real users. `geminiAllowed` keeps it to the dev
 * deployment even if PITCHFORK_PROVIDER is set somewhere else by mistake.
 */

/** Deployments where Gemini may answer. Production (astute-ant-253) is deliberately not here. */
const DEV_DEPLOYMENTS = ["wary-penguin-35"]

export function geminiAllowed(cloudUrl: string | undefined): boolean {
  if (!cloudUrl) return false
  let host: string
  try {
    host = new URL(cloudUrl).hostname
  } catch {
    return false
  }
  return DEV_DEPLOYMENTS.some((name) => host === `${name}.convex.cloud`)
}

export type Line = { who: "you" | "assistant"; text: string }

type Part = {
  text?: string
  thought?: boolean
  functionCall?: { name: string; args?: Record<string, unknown> }
  functionResponse?: { name: string; response: Record<string, unknown> }
  [key: string]: unknown
}
type Content = { role: "user" | "model"; parts: Part[] }

export function toContents(lines: Line[]): Content[] {
  return lines.map((l) => ({ role: l.who === "you" ? "user" : "model", parts: [{ text: l.text }] }))
}

/** The same tool Claude gets, in Gemini's shape. */
function tools(metrics: readonly string[], maxDays: number) {
  return [{
    functionDeclarations: [{
      name: "health_history",
      description:
        "The person's own synced health data: one value per day for one metric, oldest first, " +
        "in the metric's canonical unit (sleep in minutes, distance in metres, energy in kcal). " +
        "Call it once per metric.",
      parameters: {
        type: "object",
        properties: {
          metric: { type: "string", enum: [...metrics] },
          days: { type: "integer", description: `How many days back, 1 to ${maxDays}.` },
        },
        required: ["metric", "days"],
      },
    }],
  }]
}

export async function geminiReply(opts: {
  apiKey: string
  model: string
  system: string
  lines: Line[]
  metrics: readonly string[]
  maxDays: number
  maxRounds: number
  /** Runs one health_history call and returns what to hand back to the model. */
  lookup: (metric: string, days: number) => Promise<string>
  fetchImpl?: typeof fetch
}): Promise<string | null> {
  const doFetch = opts.fetchImpl ?? fetch
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(opts.model)}:generateContent`
  const contents = toContents(opts.lines)

  for (let round = 0; round <= opts.maxRounds; round++) {
    const response = await doFetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": opts.apiKey },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: opts.system }] },
        contents,
        tools: tools(opts.metrics, opts.maxDays),
        // On the last round it has to answer with what it already found.
        toolConfig: { functionCallingConfig: { mode: round < opts.maxRounds ? "AUTO" : "NONE" } },
      }),
    })
    if (!response.ok) throw new Error(`Gemini ${response.status}: ${(await response.text()).slice(0, 300)}`)

    const json = (await response.json()) as { candidates?: { content?: Content }[] }
    const content = json.candidates?.[0]?.content
    const parts = content?.parts ?? []
    const calls = parts.filter((p) => p.functionCall)

    if (calls.length === 0) {
      const text = parts.filter((p) => p.text && !p.thought).map((p) => p.text).join("\n").trim()
      return text || null
    }

    // The model's turn goes back unchanged, so any signatures on it stay valid.
    contents.push({ role: "model", parts })
    const results = await Promise.all(calls.map(async (p): Promise<Part> => {
      const call = p.functionCall!
      const metric = call.args?.metric
      const days = call.args?.days
      if (call.name !== "health_history" || typeof metric !== "string" || typeof days !== "number") {
        return { functionResponse: { name: call.name, response: { error: "Unknown tool or bad input" } } }
      }
      try {
        return { functionResponse: { name: call.name, response: { result: await opts.lookup(metric, days) } } }
      } catch (error) {
        return { functionResponse: { name: call.name, response: { error: String(error) } } }
      }
    }))
    contents.push({ role: "user", parts: results })
  }
  return null
}
