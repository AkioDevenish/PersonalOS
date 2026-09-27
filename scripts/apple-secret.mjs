#!/usr/bin/env node
/**
 * Turns an Apple .p8 key into the Sign in with Apple client secret. Valid six months.
 * Usage: node scripts/apple-secret.mjs --key AuthKey.p8 --team TEAMID --kid KEYID --services-id ID
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

// Apple's cap is six months.
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
