export type GemmaGenerateOptions = {
  prompt: string
  model?: string
  temperature?: number
}

export type AiRuntimeMode = 'server_gemma' | 'paid_token' | 'included_device'

export const GEMMA_MODEL = process.env.GEMMA_MODEL || process.env.OLLAMA_MODEL || 'gemma4'
export const GEMMA_URL = process.env.GEMMA_URL || process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate'
export const AI_RUNTIME_MODE = (process.env.AI_RUNTIME_MODE || 'server_gemma') as AiRuntimeMode
export const INCLUDED_DEVICE_MODEL_PACKAGE =
  process.env.INCLUDED_DEVICE_MODEL_PACKAGE || 'com.personal-os.gemma4-health'

export class DeviceLocalGemmaRequiredError extends Error {
  constructor() {
    super('This workspace is configured for included-device Gemma. Run the local model package on the phone and submit the generated report.')
    this.name = 'DeviceLocalGemmaRequiredError'
  }
}

export async function generateWithGemma({ prompt, model = GEMMA_MODEL, temperature }: GemmaGenerateOptions) {
  if (AI_RUNTIME_MODE === 'included_device') {
    throw new DeviceLocalGemmaRequiredError()
  }

  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  const apiKey = process.env.GEMMA_API_KEY || process.env.AI_PROVIDER_API_KEY
  if (AI_RUNTIME_MODE === 'paid_token' && apiKey) {
    headers.Authorization = `Bearer ${apiKey}`
  }

  const response = await fetch(GEMMA_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model,
      prompt,
      stream: false,
      options: temperature == null ? undefined : { temperature },
    }),
  })

  if (!response.ok) {
    let detail = ''
    try {
      detail = await response.text()
    } catch {
      /* ignore */
    }
    throw new Error(
      `Gemma request failed with HTTP ${response.status}: ${detail.slice(0, 500)}. ` +
        `Set GEMMA_MODEL if your Ollama model is named differently than "${model}".`,
    )
  }

  const data = await response.json()
  const text = typeof data.response === 'string' ? data.response.trim() : ''
  if (!text) {
    throw new Error('Gemma returned an empty response')
  }
  return { text, model }
}

export function modelPackageManifest() {
  return {
    runtimeMode: AI_RUNTIME_MODE,
    packageId: INCLUDED_DEVICE_MODEL_PACKAGE,
    model: GEMMA_MODEL,
    delivery: 'included-with-plan',
    supportedPlatforms: ['ios'],
    reportUploadEndpoint: '/api/well-being/device-report',
  }
}
