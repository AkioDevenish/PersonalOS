import { providerById, type Dialect, type ProviderSpec } from "./providers"

/**
 * One call shape over every platform.
 *
 * The insight routes ask for prose from a prompt; they should not know or care
 * whether that prose came from Claude, Kimi or a Gemma running on the Mac. Each
 * dialect below normalises to the same `{ text, model }` so the callers stay
 * unchanged when a user switches provider mid-week.
 *
 * Errors are deliberately readable. A BYOK system fails in ways the user can
 * actually fix — a revoked key, a model name their account cannot reach, an
 * exhausted quota — so the message has to say which of those happened rather
 * than surfacing a bare 401.
 */

export type CompleteArgs = {
  provider: string
  model?: string
  apiKey?: string | null
  prompt: string
  system?: string
  temperature?: number
  /** Local models are slow; cloud ones should not wait as long. */
  timeoutMs?: number
  maxTokens?: number
}

export type CompleteResult = { text: string; model: string; provider: string }

export class AiError extends Error {
  constructor(
    message: string,
    readonly status: number = 502,
    readonly provider?: string,
  ) {
    super(message)
    this.name = "AiError"
  }
}

/** Turns a provider's HTTP failure into something a person can act on. */
function explain(spec: ProviderSpec, status: number, body: string): AiError {
  const snippet = body.slice(0, 300)
  const who = spec.aka ? `${spec.label} (${spec.aka})` : spec.label
  if (status === 401 || status === 403) {
    return new AiError(
      `${who} rejected your API key. It may have been revoked or copied incompletely — add it again.`,
      401,
      spec.id,
    )
  }
  if (status === 404) {
    return new AiError(
      `${who} has no model by that name available to your account. Pick a different model.`,
      404,
      spec.id,
    )
  }
  if (status === 429) {
    return new AiError(
      `${who} is rate limiting you, or the account is out of credit.`,
      429,
      spec.id,
    )
  }
  return new AiError(`${who} returned HTTP ${status}: ${snippet}`, 502, spec.id)
}

async function send(url: string, init: RequestInit, timeoutMs: number, spec: ProviderSpec) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: controller.signal })
  } catch (err) {
    if ((err as Error)?.name === "AbortError") {
      throw new AiError(
        `${spec.label} did not respond within ${Math.round(timeoutMs / 1000)}s.`,
        504,
        spec.id,
      )
    }
    // A local Ollama that isn't running lands here, and the generic message
    // would send someone hunting for a bug that isn't in the code.
    if (spec.dialect === "ollama") {
      throw new AiError(
        `Couldn't reach Ollama at ${spec.baseURL}. Is the Mac awake with Ollama running?`,
        503,
        spec.id,
      )
    }
    throw new AiError(`Couldn't reach ${spec.label}: ${(err as Error).message}`, 503, spec.id)
  } finally {
    clearTimeout(timer)
  }
}

// MARK: dialects

async function openaiCompatible(
  spec: ProviderSpec,
  a: CompleteArgs,
  model: string,
  timeoutMs: number,
): Promise<string> {
  const messages: Array<{ role: string; content: string }> = []
  if (a.system) messages.push({ role: "system", content: a.system })
  messages.push({ role: "user", content: a.prompt })

  const res = await send(
    spec.baseURL,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${a.apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: a.temperature,
        max_tokens: a.maxTokens ?? 2048,
      }),
    },
    timeoutMs,
    spec,
  )
  if (!res.ok) throw explain(spec, res.status, await res.text().catch(() => ""))
  const data = await res.json()
  return data?.choices?.[0]?.message?.content ?? ""
}

async function anthropic(
  spec: ProviderSpec,
  a: CompleteArgs,
  model: string,
  timeoutMs: number,
): Promise<string> {
  const res = await send(
    spec.baseURL,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": a.apiKey ?? "",
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model,
        // Required by the Messages API, unlike the OpenAI shape.
        max_tokens: a.maxTokens ?? 2048,
        temperature: a.temperature,
        system: a.system,
        messages: [{ role: "user", content: a.prompt }],
      }),
    },
    timeoutMs,
    spec,
  )
  if (!res.ok) throw explain(spec, res.status, await res.text().catch(() => ""))
  const data = await res.json()
  // Content is a list of blocks; only the text ones concern us.
  return (data?.content ?? [])
    .filter((b: any) => b?.type === "text")
    .map((b: any) => b.text)
    .join("")
}

async function google(
  spec: ProviderSpec,
  a: CompleteArgs,
  model: string,
  timeoutMs: number,
): Promise<string> {
  // The key goes in a header rather than the query string so it stays out of
  // logs and proxy access records.
  const res = await send(
    `${spec.baseURL}/${encodeURIComponent(model)}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": a.apiKey ?? "",
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: a.prompt }] }],
        systemInstruction: a.system ? { parts: [{ text: a.system }] } : undefined,
        generationConfig: {
          temperature: a.temperature,
          maxOutputTokens: a.maxTokens ?? 2048,
        },
      }),
    },
    timeoutMs,
    spec,
  )
  if (!res.ok) throw explain(spec, res.status, await res.text().catch(() => ""))
  const data = await res.json()
  return (data?.candidates?.[0]?.content?.parts ?? [])
    .map((p: any) => p?.text ?? "")
    .join("")
}

async function ollama(
  spec: ProviderSpec,
  a: CompleteArgs,
  model: string,
  timeoutMs: number,
): Promise<string> {
  const res = await send(
    spec.baseURL,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        prompt: a.system ? `${a.system}\n\n${a.prompt}` : a.prompt,
        stream: false,
        options: a.temperature == null ? undefined : { temperature: a.temperature },
      }),
    },
    timeoutMs,
    spec,
  )
  if (!res.ok) throw explain(spec, res.status, await res.text().catch(() => ""))
  const data = await res.json()
  return typeof data?.response === "string" ? data.response : ""
}

/**
 * The on-device model has no server side. If a request lands here asking for
 * it, the app has fallen back to the network when it should have generated
 * locally — so say that, rather than reporting it as an unknown provider.
 */
async function device(spec: ProviderSpec): Promise<string> {
  throw new AiError(
    `${spec.label} runs on the phone — the app generates this locally and never asks the server for it.`,
    400,
    spec.id,
  )
}

const ADAPTERS: Record<Dialect, typeof openaiCompatible> = {
  openai: openaiCompatible,
  anthropic,
  google,
  ollama,
  device: device as unknown as typeof openaiCompatible,
}

export async function complete(a: CompleteArgs): Promise<CompleteResult> {
  const spec = providerById(a.provider)
  if (!spec) throw new AiError(`Unknown AI provider "${a.provider}"`, 400)
  if (spec.needsKey && !a.apiKey?.trim()) {
    throw new AiError(`No API key stored for ${spec.label}.`, 401, spec.id)
  }

  const model = a.model?.trim() || spec.models[0]
  // A local model on a laptop is genuinely slow; a hosted one that takes two
  // minutes has gone wrong.
  const timeoutMs = a.timeoutMs ?? (spec.dialect === "ollama" ? 180_000 : 90_000)

  const text = (await ADAPTERS[spec.dialect](spec, a, model, timeoutMs)).trim()
  if (!text) {
    throw new AiError(`${spec.label} returned an empty response.`, 502, spec.id)
  }
  return { text, model, provider: spec.id }
}

/**
 * Cheapest call that proves a key works, used when one is saved.
 *
 * Worth the round trip: a mistyped key stored silently fails later, during a
 * slow report the user was waiting on, and looks like the feature is broken
 * rather than the credential.
 */
export async function verifyKey(provider: string, apiKey: string): Promise<{ model: string }> {
  const spec = providerById(provider)
  if (!spec) throw new AiError(`Unknown AI provider "${provider}"`, 400)
  const r = await complete({
    provider,
    apiKey,
    prompt: "Reply with the single word: ok",
    temperature: 0,
    maxTokens: 8,
    timeoutMs: 30_000,
  })
  return { model: r.model }
}
