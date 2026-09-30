"use node"

import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library"
import { BUNDLE_ID } from "./app"
import { storeConfig, type StoreEnvironment } from "./appStoreConfig"

/** Checking that Apple really signed a purchase, for this app, in an environment we accept. */

const ENVIRONMENTS: Record<StoreEnvironment, Environment> = {
  production: Environment.PRODUCTION,
  sandbox: Environment.SANDBOX,
  xcode: Environment.XCODE,
}

function appleRoots(): Buffer[] {
  return (process.env.APPLE_ROOT_CERTS ?? "")
    .split("|")
    .map((b64) => b64.trim())
    .filter(Boolean)
    .map((b64) => Buffer.from(b64, "base64"))
}

/** One verifier per accepted environment, in the order they should be tried. */
function verifiers(): SignedDataVerifier[] {
  const config = storeConfig(process.env)
  const roots = appleRoots()
  if (!config.environments.includes("xcode") && roots.length === 0) {
    // Refusing is the only safe answer: granting unverified would make purchases free to anyone
    // who can send a request.
    throw new Error("Purchase verification is not configured yet")
  }
  return config.environments.map(
    (name) => new SignedDataVerifier(roots, true, ENVIRONMENTS[name], BUNDLE_ID, config.appAppleId),
  )
}

export async function verifyTransaction(signedTransaction: string): Promise<JWSTransactionDecodedPayload> {
  for (const verifier of verifiers()) {
    try {
      return await verifier.verifyAndDecodeTransaction(signedTransaction)
    } catch {
      // Try the next environment, if there is one.
    }
  }
  throw new Error("That purchase could not be verified with Apple")
}

/** A server notification from Apple, and the transaction it is about, both checked. */
export async function verifyNotification(signedPayload: string): Promise<{
  notification: ResponseBodyV2DecodedPayload
  transaction: JWSTransactionDecodedPayload | null
}> {
  for (const verifier of verifiers()) {
    let notification: ResponseBodyV2DecodedPayload
    try {
      notification = await verifier.verifyAndDecodeNotification(signedPayload)
    } catch {
      continue
    }
    const signed = notification.data?.signedTransactionInfo
    const transaction = signed ? await verifier.verifyAndDecodeTransaction(signed) : null
    return { notification, transaction }
  }
  throw new Error("That notification could not be verified with Apple")
}
