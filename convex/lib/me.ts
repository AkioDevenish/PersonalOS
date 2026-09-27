/** Who is asking, as the one id every table in this app is keyed on. */
export function userIdOf(identity: { subject: string }): string {
  return identity.subject.split("|")[0]
}
