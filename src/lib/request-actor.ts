export type RequestActor = {
  userId: string
  workspaceId: string
  authMode: 'local' | 'saas'
}

export type ActorResult =
  | { ok: true; actor: RequestActor }
  | { ok: false; status: number; error: string }

const LOCAL_USER_ID = 'local-akio'
const LOCAL_WORKSPACE_ID = 'personal-os'

function bearerToken(request: Request) {
  const header = request.headers.get('authorization')
  return header?.startsWith('Bearer ') ? header.slice(7).trim() : ''
}

export function getRequestActor(request: Request, options: { requireAuth?: boolean } = {}): ActorResult {
  const authMode = process.env.PERSONAL_OS_AUTH_MODE === 'saas' ? 'saas' : 'local'
  const configuredToken = (
    process.env.PERSONAL_OS_API_TOKEN ||
    process.env.HEALTH_INGEST_SECRET ||
    ''
  ).trim()
  const token = bearerToken(request)

  if ((options.requireAuth || authMode === 'saas') && configuredToken && token !== configuredToken) {
    return { ok: false, status: 401, error: 'Unauthorized: invalid or missing Bearer token' }
  }

  const userId = request.headers.get('x-personal-os-user-id')?.trim()
  const workspaceId = request.headers.get('x-personal-os-workspace-id')?.trim()

  if (authMode === 'saas' && !userId) {
    return { ok: false, status: 400, error: 'Missing x-personal-os-user-id header' }
  }

  return {
    ok: true,
    actor: {
      userId: userId || process.env.PERSONAL_OS_LOCAL_USER_ID || LOCAL_USER_ID,
      workspaceId: workspaceId || process.env.PERSONAL_OS_LOCAL_WORKSPACE_ID || LOCAL_WORKSPACE_ID,
      authMode,
    },
  }
}
