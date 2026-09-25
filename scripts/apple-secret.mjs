#!/usr/bin/env node
/**
 * Turns an Apple private key into the client secret Sign in with Apple wants.
 *
 * Google and Facebook hand you a secret string you paste and forget. Apple
 * does not: it gives you a .p8 signing key, and the "secret" is a JWT you
 * sign with it yourself. Apple refuses one older than six months, so this is
 * a thing you run again twice a year rather than a thing you do once.
 *
 * The .p8 never leaves this machine — only the JWT it produces goes to the
 * deployment, and the JWT expires on its own.
 *
 *   node scripts/apple-secret.mjs \
 *     --key ~/Downloads/AuthKey_ABC123XYZ.p8 \
 *     --team TEAMID1234 \
 *     --kid ABC123XYZ \
 *     --services-id ADEVSTUDIO.PersonalOSHealth.signin
 *
 * Then, to put it on the deployment:
 *
 *   npx convex env set AUTH_APPLE_SECRET "<the printed JWT>"
 */
import { readFileSync } from "node:fs"
import { SignJWT, importPKCS8 } from "jose"

const args = process.argv.slice(2)
const flag = (name) => {
  const i = args.indexOf(`--${name}`)
  return i === -1 ? undefined : args[i + 1]
}

const keyPath = flag("key")
const team = flag("team")
const kid = flag("kid")
const servicesId = flag("services-id")

const missing = [
  ["--key", keyPath],
  ["--team", team],
  ["--kid", kid],
  ["--services-id", servicesId],
].filter(([, value]) => !value).map(([name]) => name)

if (missing.length) {
  console.error(`Missing ${missing.join(", ")}. See the comment at the top of this file.`)
  process.exit(1)
}

// Apple's cap is six months. Anything longer is rejected outright, so this
// asks for exactly that and prints the date it stops working.
const SIX_MONTHS = 15777000
const now = Math.floor(Date.now() / 1000)
const expires = now + SIX_MONTHS

const key = await importPKCS8(readFileSync(keyPath, "utf8"), "ES256")

const jwt = await new SignJWT({})
  .setProtectedHeader({ alg: "ES256", kid })
  .setIssuer(team)
  .setIssuedAt(now)
  .setExpirationTime(expires)
  .setAudience("https://appleid.apple.com")
  .setSubject(servicesId)
  .sign(key)

console.log(jwt)
console.error(`\nGood until ${new Date(expires * 1000).toDateString()}. Run this again before then.`)
