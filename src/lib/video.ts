/**
 * Video calls, carried by Daily.
 *
 * Rooms are private and every join is a short-lived token. A public room URL
 * is a link anybody who sees it can walk into, which for a health
 * consultation is not a risk worth taking for the convenience of a simpler
 * call.
 *
 * The room expires an hour after it is made and tokens sooner still, so a link
 * that leaks is worth nothing by the time it does.
 */

const BASE = "https://api.daily.co/v1"

export function videoConfigured() {
  return Boolean(process.env.DAILY_API_KEY)
}

function headers() {
  return {
    Authorization: `Bearer ${process.env.DAILY_API_KEY}`,
    "Content-Type": "application/json",
  }
}

/** Makes the room for a session, named after it so it is never guessed. */
export async function createRoom(reference: string): Promise<string> {
  const response = await fetch(`${BASE}/rooms`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      name: `pos-${reference}`.toLowerCase().slice(0, 40),
      privacy: "private",
      properties: {
        exp: Math.floor(Date.now() / 1000) + 60 * 60,
        // Somebody should see themselves, and choose their camera, before
        // they are in front of a stranger.
        enable_prejoin_ui: true,
        enable_chat: true,
      },
    }),
  })

  const json = await response.json().catch(() => null)
  // A room that already exists is a retry, not a failure: reuse it.
  if (response.status === 400 && String(json?.info ?? "").includes("already exists")) {
    return `pos-${reference}`.toLowerCase().slice(0, 40)
  }
  if (!response.ok || !json?.name) {
    throw new Error(json?.info ?? `Could not open a room (${response.status})`)
  }
  return json.name
}

/**
 * A token to enter one room, once, soon.
 *
 * Twenty minutes is long enough to join a call that starts late and short
 * enough that a token copied out of a log is useless.
 */
export async function mintToken(room: string, name: string): Promise<string> {
  const response = await fetch(`${BASE}/meeting-tokens`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      properties: {
        room_name: room,
        user_name: name,
        exp: Math.floor(Date.now() / 1000) + 60 * 20,
      },
    }),
  })

  const json = await response.json().catch(() => null)
  if (!response.ok || !json?.token) {
    throw new Error(json?.info ?? `Could not authorise the call (${response.status})`)
  }
  return json.token
}

export function roomURL(room: string, token: string) {
  const domain = process.env.DAILY_DOMAIN
  const base = domain ? `https://${domain}.daily.co/${room}` : ""
  return base ? `${base}?t=${token}` : ""
}
