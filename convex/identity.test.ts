/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { describe, expect, test } from "vitest"
import { api } from "./_generated/api"
import schema from "./schema"
import { userIdOf } from "./lib/me"

const modules = import.meta.glob("./**/*.ts")

/** Under Convex Auth a subject is `userId|sessionId`, a new value at every sign-in. */
describe("one person across sign-ins", () => {
  const first = { subject: "user_42|session_a", tokenIdentifier: "https://x|user_42|session_a" }
  const again = { subject: "user_42|session_b", tokenIdentifier: "https://x|user_42|session_b" }
  const other = { subject: "user_99|session_c", tokenIdentifier: "https://x|user_99|session_c" }

  test("the user id is the stable half", () => {
    expect(userIdOf(first)).toBe("user_42")
    expect(userIdOf(again)).toBe("user_42")
    // A Clerk id has no divider and passes through unchanged.
    expect(userIdOf({ subject: "user_2abc" })).toBe("user_2abc")
  })

  test("what was written in one session is there in the next", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(first).mutation(api.finance.add, {
      date: Date.now(), minor: -1250, currency: "USD", category: "Food",
    })
    const ledger = await t.withIdentity(again).query(api.finance.ledger, { from: 0, to: Date.now() + 1 })
    expect(ledger.entries).toHaveLength(1)
  })

  test("and is still nobody else's", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(first).mutation(api.finance.add, {
      date: Date.now(), minor: -1250, currency: "USD", category: "Food",
    })
    const theirs = await t.withIdentity(other).query(api.finance.ledger, { from: 0, to: Date.now() + 1 })
    expect(theirs.entries).toHaveLength(0)
  })
})
