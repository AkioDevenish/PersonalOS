/**
 * Who is asking, as the one id every table in this app is keyed on.
 *
 * Under Convex Auth the identity's subject is `userId|sessionId`: a new value
 * every time somebody signs in again. Keying data on that directly would make
 * every sign-in a stranger to their own ledger, so everything goes through
 * here and gets the stable half.
 *
 * Before Convex Auth it was a Clerk user id with no divider, which this also
 * handles unchanged — so it is safe on either side of the switch.
 */
export function userIdOf(identity: { subject: string }): string {
  return identity.subject.split("|")[0]
}
