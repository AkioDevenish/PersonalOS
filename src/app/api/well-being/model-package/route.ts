import { NextResponse } from 'next/server'
import { modelPackageManifest } from '@/lib/gemma'
import { getRequestActor } from '@/lib/request-actor'

export async function GET(request: Request) {
  const auth = getRequestActor(request)
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status })
  }

  return NextResponse.json({
    success: true,
    userId: auth.actor.userId,
    workspaceId: auth.actor.workspaceId,
    package: modelPackageManifest(),
  })
}
