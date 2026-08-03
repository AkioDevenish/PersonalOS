/**
 * The AI platforms a user can bring a key for.
 *
 * Most of these speak the OpenAI chat-completions shape, which is why the
 * registry carries a `dialect` rather than a bespoke adapter per entry — adding
 * another OpenAI-compatible vendor is one object here and no new code. Only
 * Anthropic and Google differ enough to need their own adapter.
 *
 * `keyPrefix` is a cheap client-side sanity check, not validation. The real
 * check is a live call against the provider when the key is saved, because a
 * well-formed key that has been revoked is indistinguishable from a good one
 * until you use it.
 */

export type Dialect = "openai" | "anthropic" | "google" | "ollama"

export type ProviderSpec = {
  id: string
  label: string
  /** What the user would call it, if that differs from the company. */
  aka?: string
  dialect: Dialect
  baseURL: string
  /** Absent for local runtimes that need no credential. */
  needsKey: boolean
  keyPrefix?: string
  /** First entry is the default when a user picks this provider. */
  models: string[]
  consoleURL?: string
}

export const PROVIDERS: ProviderSpec[] = [
  {
    id: "anthropic",
    label: "Anthropic",
    aka: "Claude",
    dialect: "anthropic",
    baseURL: "https://api.anthropic.com/v1/messages",
    needsKey: true,
    keyPrefix: "sk-ant-",
    models: [
      "claude-opus-4-5",
      "claude-sonnet-4-5",
      "claude-haiku-4-5",
    ],
    consoleURL: "https://console.anthropic.com/settings/keys",
  },
  {
    id: "openai",
    label: "OpenAI",
    aka: "ChatGPT",
    dialect: "openai",
    baseURL: "https://api.openai.com/v1/chat/completions",
    needsKey: true,
    keyPrefix: "sk-",
    models: ["gpt-5", "gpt-5-mini", "gpt-4.1", "o4-mini"],
    consoleURL: "https://platform.openai.com/api-keys",
  },
  {
    id: "moonshot",
    label: "Moonshot",
    aka: "Kimi",
    dialect: "openai",
    baseURL: "https://api.moonshot.ai/v1/chat/completions",
    needsKey: true,
    keyPrefix: "sk-",
    models: ["kimi-k2-0905-preview", "moonshot-v1-128k", "moonshot-v1-32k"],
    consoleURL: "https://platform.moonshot.ai/console/api-keys",
  },
  {
    id: "google",
    label: "Google",
    aka: "Gemini",
    dialect: "google",
    // The model name is a path segment for this API, so it is appended at call
    // time rather than stored here.
    baseURL: "https://generativelanguage.googleapis.com/v1beta/models",
    needsKey: true,
    models: ["gemini-2.5-pro", "gemini-2.5-flash"],
    consoleURL: "https://aistudio.google.com/app/apikey",
  },
  {
    id: "deepseek",
    label: "DeepSeek",
    dialect: "openai",
    baseURL: "https://api.deepseek.com/chat/completions",
    needsKey: true,
    keyPrefix: "sk-",
    models: ["deepseek-chat", "deepseek-reasoner"],
    consoleURL: "https://platform.deepseek.com/api_keys",
  },
  {
    id: "xai",
    label: "xAI",
    aka: "Grok",
    dialect: "openai",
    baseURL: "https://api.x.ai/v1/chat/completions",
    needsKey: true,
    keyPrefix: "xai-",
    models: ["grok-4", "grok-3", "grok-3-mini"],
    consoleURL: "https://console.x.ai",
  },
  {
    id: "groq",
    label: "Groq",
    dialect: "openai",
    baseURL: "https://api.groq.com/openai/v1/chat/completions",
    needsKey: true,
    keyPrefix: "gsk_",
    models: ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"],
    consoleURL: "https://console.groq.com/keys",
  },
  {
    id: "mistral",
    label: "Mistral",
    dialect: "openai",
    baseURL: "https://api.mistral.ai/v1/chat/completions",
    needsKey: true,
    models: ["mistral-large-latest", "mistral-small-latest"],
    consoleURL: "https://console.mistral.ai/api-keys",
  },
  {
    id: "ollama",
    label: "Ollama",
    aka: "on your Mac",
    dialect: "ollama",
    // Overridable because the Mac's address is not knowable at build time.
    baseURL: process.env.OLLAMA_URL?.trim() || "http://127.0.0.1:11434/api/generate",
    needsKey: false,
    models: [
      process.env.GEMMA_MODEL?.trim() || process.env.OLLAMA_MODEL?.trim() || "gemma4",
    ],
  },
]

export function providerById(id: string): ProviderSpec | undefined {
  return PROVIDERS.find((p) => p.id === id)
}

/** The shape the app is allowed to see: no secrets, ever. */
export type PublicProvider = {
  id: string
  label: string
  aka?: string
  needsKey: boolean
  keyPrefix?: string
  models: string[]
  consoleURL?: string
}

export function publicCatalogue(): PublicProvider[] {
  return PROVIDERS.map(({ id, label, aka, needsKey, keyPrefix, models, consoleURL }) => ({
    id,
    label,
    aka,
    needsKey,
    keyPrefix,
    models,
    consoleURL,
  }))
}

/**
 * Last four characters, for showing a user which key is stored without being
 * able to reconstruct it. Short keys are masked entirely rather than mostly
 * revealed.
 */
export function last4(key: string): string {
  const k = key.trim()
  return k.length < 8 ? "••••" : k.slice(-4)
}
