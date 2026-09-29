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
    await t.withIdentity(first).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Sadza" })
    const book = await t.withIdentity(again).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all.find((d) => d.dish === "Sadza")?.mine).toBe(true)
  })

  test("and is still nobody else's", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(first).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Sadza" })
    const book = await t.withIdentity(other).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all.find((d) => d.dish === "Sadza")?.mine).toBe(false)
  })
})
