"use node"

import { v } from "convex/values"
import http2 from "node:http2"
import jwt from "jsonwebtoken"
import { internalAction } from "./_generated/server"
import { internal } from "./_generated/api"

/**
 * Sending a notification to somebody's lock screen.
 *
 * A real push, delivered by Apple, so it arrives whether or not the app is
 * running. The app's own notifications were local: they could only appear
 * while it was open, which is no use for the thing worth telling somebody —
 * that a practitioner has replied while they were elsewhere.
 *
 * Apple requires HTTP/2 for this, which `fetch` does not speak, so it goes
 * through node:http2 directly.
 *
 * Environment variables on the Convex deployment, all from the paid developer
 * account. Without them nothing is sent and nothing fails loudly: a push that
 * cannot be delivered must never take down the reply that triggered it.
 *
 *   APNS_KEY_ID      the key's 10-character id
 *   APNS_TEAM_ID     the 10-character team id
 *   APNS_P8          the .p8 private key, PEM, newlines as \n
 *   APNS_ENVIRONMENT "production", or "sandbox" for development builds
 */

const BUNDLE_ID = "ADEVSTUDIO.PersonalOSHealth"
const HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
}

function providerToken(): string | null {
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID
  const key = process.env.APNS_P8?.replace(/\\n/g, "\n")
  if (!keyId || !teamId || !key) return null
  return jwt.sign({ iss: teamId, iat: Math.floor(Date.now() / 1000) }, key, {
    algorithm: "ES256",
    header: { alg: "ES256", kid: keyId },
  })
}

type Sent = { delivered: number; forgotten: number; skipped: boolean }

export const send = internalAction({
  args: {
    userId: v.string(),
    title: v.string(),
    body: v.string(),
    /** Which screen the tap should open. */
    route: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<Sent> => {
    const authorization = providerToken()
    if (!authorization) return { delivered: 0, forgotten: 0, skipped: true }

    const tokens: string[] = await ctx.runQuery(internal.devices.forUser, { userId: args.userId })
    if (tokens.length === 0) return { delivered: 0, forgotten: 0, skipped: false }

    const host = process.env.APNS_ENVIRONMENT === "production" ? HOSTS.production : HOSTS.sandbox
    const payload = JSON.stringify({
      aps: {
        alert: { title: args.title, body: args.body },
        sound: "default",
      },
      route: args.route ?? null,
    })

    const client = http2.connect(host)
    let delivered = 0
    const dead: string[] = []

    try {
      await Promise.all(
        tokens.map(
          (token) =>
            new Promise<void>((resolve) => {
              const request = client.request({
                ":method": "POST",
                ":path": `/3/device/${token}`,
                authorization: `bearer ${authorization}`,
                "apns-topic": BUNDLE_ID,
                "apns-push-type": "alert",
                "content-type": "application/json",
              })
              let status = 0
              request.on("response", (headers) => {
                status = Number(headers[":status"] ?? 0)
              })
              request.on("error", () => resolve())
              request.on("end", () => {
                if (status === 200) delivered += 1
                // 410 is Apple saying the app is gone from that device; 400
                // with BadDeviceToken is the same thing said differently.
                else if (status === 410 || status === 400) dead.push(token)
                resolve()
              })
              request.end(payload)
            }),
        ),
      )
    } finally {
      client.close()
    }

    for (const token of dead) {
      await ctx.runMutation(internal.devices.forget, { token })
    }
    return { delivered, forgotten: dead.length, skipped: false }
  },
})
