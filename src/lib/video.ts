import crypto from "crypto"

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

/**
 * Which service carries the call.
 *
 * Jitsi wins when it is configured, because a server you run yourself has no
 * per-minute meter and no third party sitting in the middle of a medical
 * conversation. Daily is the fallback for anyone not running one.
 */
export type VideoProvider = "jitsi" | "daily"

export function videoProvider(): VideoProvider | null {
  if (jitsiConfigured()) return "jitsi"
  if (process.env.DAILY_API_KEY && process.env.DAILY_DOMAIN) return "daily"
  return null
}

export function jitsiConfigured() {
  return Boolean(process.env.JITSI_DOMAIN && process.env.JITSI_APP_ID && process.env.JITSI_APP_SECRET)
}

export function videoConfigured() {
  return videoProvider() !== null
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


// MARK: Jitsi

/**
 * A room on your own Jitsi, entered with a signed token.
 *
 * Nothing is created in advance: a Jitsi room exists the moment somebody with
 * a valid token opens its name, so there is no API to call and no room to
 * clean up afterwards.
 *
 * The token is what makes it private. Without `jitsi-meet-tokens` configured
 * on the server, anybody who learns a room's name can walk into it — which for
 * two people discussing someone's health is the whole problem. With it, the
 * server refuses anyone whose token it cannot verify, and each token names one
 * room and expires.
 */
function base64url(input: Buffer | string) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")
}

function jitsiToken(room: string, name: string): string {
  const header = { alg: "HS256", typ: "JWT" }
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    // Jitsi's own default audience unless the deployment overrides it.
    aud: process.env.JITSI_APP_AUD ?? "jitsi",
    iss: process.env.JITSI_APP_ID,
    sub: process.env.JITSI_DOMAIN,
    // Named rather than "*", so a token for one consultation cannot open
    // somebody else's.
    room,
    nbf: now - 10,
    exp: now + 60 * 20,
    context: { user: { name } },
  }

  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`
  const signature = crypto
    .createHmac("sha256", process.env.JITSI_APP_SECRET!)
    .update(signingInput)
    .digest()

  return `${signingInput}.${base64url(signature)}`
}

/**
 * The link to hand the phone.
 *
 * The config fragment turns off the things a consultation does not want: the
 * pre-join screen asking for a display name we already know, the invite
 * button, and the watermark.
 */
export function jitsiURL(reference: string, name: string): string {
  const room = `pos-${reference}`.toLowerCase().slice(0, 40)
  const token = jitsiToken(room, name)
  const options = [
    "config.prejoinPageEnabled=false",
    "config.disableInviteFunctions=true",
    "interfaceConfig.SHOW_JITSI_WATERMARK=false",
  ].join("&")
  return `https://${process.env.JITSI_DOMAIN}/${room}?jwt=${token}#${options}`
}
