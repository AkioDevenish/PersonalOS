import { NextResponse } from "next/server"
import { AiError, verifyKey } from "@/lib/ai/complete"
import { deleteKey, readSettings, requireCaller, saveKey } from "@/lib/ai/user-model"
import { providerById } from "@/lib/ai/providers"

export const dynamic = "force-dynamic"

/**
 * Add or remove a bring-your-own-key credential.
 *
 * A submitted key is proved before it is stored: one small live call to the
 * provider. Storing an unverified key means the failure surfaces much later,
 * in the middle of a slow report the user was waiting on, where it reads as
 * "the app is broken" rather than "that key is wrong". Thirty seconds at entry
 * is the cheaper place to find out.
 *
 * Nothing here logs the key, echoes it back, or returns it in any response.
 */
export async function POST(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const body = await request.json().catch(() => null)
  const provider = (body as any)?.provider
  const apiKey = (body as any)?.apiKey

  if (typeof provider !== "string" || !provider) {
    return NextResponse.json({ error: '"provider" is required' }, { status: 400 })
  }
  if (typeof apiKey !== "string" || !apiKey.trim()) {
    return NextResponse.json({ error: '"apiKey" is required' }, { status: 400 })
  }

  const spec = providerById(provider)
  if (!spec) {
    return NextResponse.json({ error: `Unknown AI provider "${provider}"` }, { status: 400 })
  }

  try {
    // Prove it works, then keep it.
    const { model } = await verifyKey(provider, apiKey.trim())
    await saveKey(caller, provider, apiKey.trim())
    const { keys, selection } = await readSettings(caller)
    return NextResponse.json({ ok: true, verifiedWith: model, keys, selection })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Couldn't save that key"
    const status = error instanceof AiError ? error.status : 500
    // console.error is deliberately not called with the request body here —
    // an API key in a log file outlives every other precaution in this route.
    return NextResponse.json({ error: message }, { status })
  }
}

export async function DELETE(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const provider = new URL(request.url).searchParams.get("provider")
  if (!provider) {
    return NextResponse.json({ error: '"provider" is required' }, { status: 400 })
  }

  try {
    await deleteKey(caller, provider)
    const { keys, selection } = await readSettings(caller)
    return NextResponse.json({ ok: true, keys, selection })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Couldn't remove that key"
    const status = error instanceof AiError ? error.status : 500
    return NextResponse.json({ error: message }, { status })
  }
}
