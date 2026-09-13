import { auth } from "@clerk/nextjs/server"
import { getConvexClient } from "@/lib/convex-client"
import { api } from "../../../convex/_generated/api"
import { decryptToken, encryptToken, hasEncryptionKey } from "@/lib/health/token-crypto"
import { complete, AiError, type CompleteResult } from "./complete"
import { providerById, last4 as tail } from "./providers"

/**
 * The bridge between a signed-in user and whichever model they chose.
 *
 * Everything here runs with the caller's own Convex credential, forwarded from
 * the request. The phone authenticates with Clerk and sends the Convex-
 * templated JWT as its bearer token; re-minting with getToken() only works for
 * cookie-bearing requests, so bearer first and mint second — the same ordering
 * the ingest route settled on after this exact bug cost an afternoon.
 */

export type Caller = { userId: string; token: string }

export async function requireCaller(request: Request): Promise<Caller | null> {
  const { userId, getToken } = await auth()
  if (!userId) return null
  const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim()
  const token = bearer || (await getToken({ template: "convex" }))
  if (!token) return null
  return { userId, token }
}

/** Stores a key, encrypted, after proving it actually works. */
export async function saveKey(caller: Caller, provider: string, apiKey: string) {
  const spec = providerById(provider)
  if (!spec) throw new AiError(`Unknown AI provider "${provider}"`, 400)
  if (!spec.needsKey) throw new AiError(`${spec.label} does not take an API key.`, 400)
  if (!hasEncryptionKey()) {
    throw new AiError(
      "This server has no TOKEN_ENCRYPTION_KEY, so it cannot store credentials safely. Generate one with: openssl rand -base64 32",
      500,
    )
  }

  const convex = getConvexClient(caller.token)
  await convex.mutation(api.ai.keys.store, {
    provider,
    api_key: encryptToken(apiKey.trim()),
    last4: tail(apiKey),
  })
}

export async function deleteKey(caller: Caller, provider: string) {
  const convex = getConvexClient(caller.token)
  await convex.mutation(api.ai.keys.remove, { provider })
}

async function keyFor(caller: Caller, provider: string): Promise<string | null> {
  const convex = getConvexClient(caller.token)
  const row = await convex.query(api.ai.keys.envelopeFor, { provider })
  if (!row?.api_key) return null
  try {
    return decryptToken(row.api_key)
  } catch {
    // A key encrypted under a rotated TOKEN_ENCRYPTION_KEY can never be
    // recovered. Say so, rather than reporting it as the provider's fault.
    throw new AiError(
      `The stored ${provider} key can't be decrypted — it was saved under a different encryption key. Add it again.`,
      400,
      provider,
    )
  }
}

/** What the app should show: catalogue, which keys exist, current choice. */
export async function readSettings(caller: Caller) {
  const convex = getConvexClient(caller.token)
  const [keys, pref] = await Promise.all([
    convex.query(api.ai.keys.summary, {}),
    convex.query(api.ai.preferences.get, {}),
  ])
  return {
    keys: keys ?? [],
    selection: pref ? { provider: pref.provider, model: pref.model } : null,
  }
}

export async function setSelection(caller: Caller, provider: string, model: string) {
  const spec = providerById(provider)
  if (!spec) throw new AiError(`Unknown AI provider "${provider}"`, 400)
  const convex = getConvexClient(caller.token)
  await convex.mutation(api.ai.preferences.set, {
    provider,
    model: model.trim() || spec.models[0],
  })
}

/**
 * Generate prose as this user, on the model they picked.
 *
 * Falls back to the server's own Ollama when nothing has been chosen, so an
 * account that has never opened the settings screen behaves exactly as it did
 * before any of this existed.
 */
export async function generateForUser(
  caller: Caller,
  prompt: string,
  opts: { system?: string; temperature?: number; maxTokens?: number } = {},
): Promise<CompleteResult> {
  const convex = getConvexClient(caller.token)
  const pref = await convex.query(api.ai.preferences.get, {})

  const provider = pref?.provider ?? "ollama"
  const spec = providerById(provider)
  if (!spec) throw new AiError(`Unknown AI provider "${provider}"`, 400)

  const apiKey = spec.needsKey ? await keyFor(caller, provider) : null
  if (spec.needsKey && !apiKey) {
    throw new AiError(
      `No API key stored for ${spec.label}. Add one in Settings, or switch models.`,
      401,
      provider,
    )
  }

  return complete({
    provider,
    model: pref?.model,
    apiKey,
    prompt,
    ...opts,
  })
}
