"use node"

import { v } from "convex/values"
import { action } from "../_generated/server"
import { api } from "../_generated/api"
import crypto from "crypto"

/**
 * Opening the video call for a session, on Jitsi.
 *
 * An action rather than a route, so the phone reaches it with no web server
 * in between, and the signing secret stays on Convex's machines. A secret in
 * an app binary is a secret anybody can read out of it.
 *
 * Nothing is created in advance: a Jitsi room exists the moment somebody
 * opens its name. That is convenient and it is also the danger, which is what
 * the token is for.
 */

function base64url(input: Buffer | string) {
  return Buffer.from(input).toString("base64")
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

/**
 * A token naming one room, good for twenty minutes.
 *
 * Only minted when the deployment is running `jitsi-meet-tokens`. Without it
 * a signed link would simply be refused, so an unsigned URL is the correct
 * thing to hand back — but see the warning the caller gets, because an
 * unsigned room is one anybody who learns the name can walk into.
 */
function token(room: string, name: string): string {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "HS256", typ: "JWT" }
  const payload = {
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
  const input = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`
  const signature = crypto
    .createHmac("sha256", process.env.JITSI_APP_SECRET!)
    .update(input)
    .digest()
  return `${input}.${base64url(signature)}`
}

export const join = action({
  args: { id: v.id("consults") },
  handler: async (ctx, args): Promise<{ url: string; secured: boolean }> => {
    const session = await ctx.runQuery(api.health.consult.billing, { id: args.id })

    if (session.kind !== "video") throw new Error("That session is not a call")
    // An unpaid call is not a call. The written conversation stays open, but
    // a practitioner's time is not given away by a URL.
    if (session.payment_status === "pending") throw new Error("This call has not been paid for")

    const domain = process.env.JITSI_DOMAIN
    if (!domain) throw new Error("No video service is connected yet.")

    // The session id, so a room cannot be guessed from a name or a date.
    const room = `pos-${session.id}`.toLowerCase().slice(0, 40)
    const signed = Boolean(process.env.JITSI_APP_ID && process.env.JITSI_APP_SECRET)

    const options = [
      "config.prejoinPageEnabled=false",
      "config.disableInviteFunctions=true",
      "interfaceConfig.SHOW_JITSI_WATERMARK=false",
    ].join("&")

    const url = signed
      ? `https://${domain}/${room}?jwt=${token(room, "You")}#${options}`
      : `https://${domain}/${room}#${options}`

    // The screen says so when a room is not signed, rather than the app
    // quietly pretending a public room is private.
    return { url, secured: signed }
  },
})
