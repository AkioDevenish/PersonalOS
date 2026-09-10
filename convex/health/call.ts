"use node"

import { v } from "convex/values"
import { action } from "../_generated/server"
import { api } from "../_generated/api"
import crypto from "crypto"

/**
 * Opening the video call for a session.
 *
 * An action rather than a route, so the phone can reach it without a web
 * server in the middle. The secrets stay here: Convex holds them as
 * environment variables and this runs on Convex's own machines, so nothing
 * that could mint a room ever travels to a device.
 *
 * Jitsi first when it is configured — a server you run has no per-minute
 * meter and no third party inside a medical conversation. Daily otherwise.
 */

function jitsiConfigured() {
  return Boolean(
    process.env.JITSI_DOMAIN && process.env.JITSI_APP_ID && process.env.JITSI_APP_SECRET
  )
}

function base64url(input: Buffer | string) {
  return Buffer.from(input).toString("base64")
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function jitsiURL(room: string, name: string) {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "HS256", typ: "JWT" }
  const payload = {
    aud: process.env.JITSI_APP_AUD ?? "jitsi",
    iss: process.env.JITSI_APP_ID,
    sub: process.env.JITSI_DOMAIN,
    // One room, not the wildcard, so a token cannot open somebody else's.
    room,
    nbf: now - 10,
    exp: now + 60 * 20,
    context: { user: { name } },
  }
  const input = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`
  const signature = crypto
    .createHmac("sha256", process.env.JITSI_APP_SECRET!)
    .update(input)
    .digest()

  const options = [
    "config.prejoinPageEnabled=false",
    "config.disableInviteFunctions=true",
    "interfaceConfig.SHOW_JITSI_WATERMARK=false",
  ].join("&")
  return `https://${process.env.JITSI_DOMAIN}/${room}?jwt=${input}.${base64url(signature)}#${options}`
}

async function daily(path: string, body: unknown) {
  const response = await fetch(`https://api.daily.co/v1${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.DAILY_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  })
  const json = await response.json().catch(() => null)
  return { ok: response.ok, status: response.status, json }
}

export const join = action({
  args: { id: v.id("consults") },
  handler: async (ctx, args): Promise<{ url: string }> => {
    const session = await ctx.runQuery(api.health.consult.billing, { id: args.id })

    if (session.kind !== "video") throw new Error("That session is not a call")
    // An unpaid call is not a call. The written conversation stays open, but
    // a practitioner's time is not given away by a URL.
    if (session.payment_status === "pending") throw new Error("This call has not been paid for")

    const room = `pos-${session.id}`.toLowerCase().slice(0, 40)

    if (jitsiConfigured()) {
      // Nothing to create: a Jitsi room exists the moment a valid token opens
      // its name.
      return { url: jitsiURL(room, "You") }
    }

    if (!process.env.DAILY_API_KEY || !process.env.DAILY_DOMAIN) {
      throw new Error("No video service is connected yet.")
    }

    const made = await daily("/rooms", {
      name: room,
      privacy: "private",
      properties: {
        exp: Math.floor(Date.now() / 1000) + 60 * 60,
        enable_prejoin_ui: true,
        enable_chat: true,
      },
    })
    // Already existing is a rejoin, not a failure.
    const exists = made.status === 400 && String(made.json?.info ?? "").includes("already exists")
    if (!made.ok && !exists) {
      throw new Error(made.json?.info ?? `Could not open a room (${made.status})`)
    }

    const minted = await daily("/meeting-tokens", {
      properties: {
        room_name: room,
        user_name: "You",
        // Twenty minutes: long enough to join a call that starts late, short
        // enough that a token copied out of a log is useless.
        exp: Math.floor(Date.now() / 1000) + 60 * 20,
      },
    })
    if (!minted.ok || !minted.json?.token) {
      throw new Error(minted.json?.info ?? "Could not authorise the call")
    }

    return { url: `https://${process.env.DAILY_DOMAIN}.daily.co/${room}?t=${minted.json.token}` }
  },
})
