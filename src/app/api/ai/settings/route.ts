import { NextResponse } from "next/server"
import { publicCatalogue } from "@/lib/ai/providers"
import { readSettings, requireCaller, setSelection } from "@/lib/ai/user-model"
import { AiError } from "@/lib/ai/complete"

export const dynamic = "force-dynamic"

/**
 * Everything the settings screen needs in one round trip: the catalogue of
 * platforms, which of them this user has a key for (last four characters
 * only), and which model is currently selected.
 *
 * No response from this file ever contains an API key. The catalogue is
 * static, the key list is masked at the database layer, and the selection is
 * just two strings.
 */
export async function GET(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }
  try {
    const { keys, selection } = await readSettings(caller)
    return NextResponse.json({
      providers: publicCatalogue(),
      keys,
      selection,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to read settings"
    const status = error instanceof AiError ? error.status : 500
    return NextResponse.json({ error: message }, { status })
  }
}

/** Change which platform and model insights run on. */
export async function PUT(request: Request) {
  const caller = await requireCaller(request)
  if (!caller) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
  }

  const body = await request.json().catch(() => null)
  const provider = (body as any)?.provider
  const model = (body as any)?.model

  if (typeof provider !== "string" || !provider) {
    return NextResponse.json({ error: '"provider" is required' }, { status: 400 })
  }

  try {
    await setSelection(caller, provider, typeof model === "string" ? model : "")
    const { keys, selection } = await readSettings(caller)
    return NextResponse.json({ ok: true, keys, selection })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to save selection"
    const status = error instanceof AiError ? error.status : 500
    return NextResponse.json({ error: message }, { status })
  }
}
