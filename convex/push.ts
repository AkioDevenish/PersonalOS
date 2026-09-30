"use node"

import { v } from "convex/values"
import http2 from "node:http2"
import jwt from "jsonwebtoken"
import { internalAction } from "./_generated/server"
import { internal } from "./_generated/api"
import { BUNDLE_ID } from "./lib/app"
import { apnsHost, isGone } from "./lib/apns"

/** Sending a notification to somebody's lock screen. */

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
    const host = apnsHost(process.env.APNS_ENVIRONMENT)
    if (!authorization || !host) return { delivered: 0, forgotten: 0, skipped: true }

    const tokens: string[] = await ctx.runQuery(internal.devices.forUser, { userId: args.userId })
    if (tokens.length === 0) return { delivered: 0, forgotten: 0, skipped: false }

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
              let body = ""
              request.setEncoding("utf8")
              request.on("response", (headers) => {
                status = Number(headers[":status"] ?? 0)
              })
              request.on("data", (chunk: string) => {
                body += chunk
              })
              request.on("error", () => resolve())
              request.on("end", () => {
                if (status === 200) delivered += 1
                else if (isGone(status, body)) dead.push(token)
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
