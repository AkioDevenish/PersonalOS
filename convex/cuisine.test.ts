/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { describe, expect, test } from "vitest"
import { api } from "./_generated/api"
import schema from "./schema"
import { CURATED, curatedFor } from "./health/dishes"

const modules = import.meta.glob("./**/*.ts")

const me = { subject: "user_1|session_a", tokenIdentifier: "https://x|user_1|session_a" }
const you = { subject: "user_2|session_b", tokenIdentifier: "https://x|user_2|session_b" }
const them = { subject: "user_3|session_c", tokenIdentifier: "https://x|user_3|session_c" }

describe("the written-down dishes", () => {
  test("no country repeats a dish or lists variations of one", () => {
    for (const [country, dishes] of Object.entries(CURATED)) {
      const keys = dishes.map((d) => d.trim().toLowerCase())
      expect(new Set(keys).size, `${country} repeats a dish`).toBe(keys.length)

      for (const a of keys) {
        for (const b of keys) {
          if (a === b) continue
          expect(
            b.startsWith(a + " de ") || b.startsWith(a + " with "),
            `${country}: "${b}" looks like a variation of "${a}"`,
          ).toBe(false)
        }
      }
    }
  })

  test("Trinidad has Trinidadian food, not its neighbours'", () => {
    const tt = curatedFor("TT").map((d) => d.toLowerCase())
    for (const dish of ["doubles", "roti", "pelau", "callaloo", "bake and shark"]) {
      expect(tt, `TT is missing ${dish}`).toContain(dish)
    }
    for (const wrong of ["ackee and saltfish", "rice and peas", "bunny chow", "fish and chips"]) {
      expect(tt, `TT should not claim ${wrong}`).not.toContain(wrong)
    }
  })
})

describe("what the prompt may cook from", () => {
  test("a written-down country needs no votes", async () => {
    const t = convexTest(schema, modules)
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.canon).toContain("Doubles")
    expect(book.canon.length).toBe(curatedFor("TT").length)
  })

  test("a country nobody wrote down starts empty", async () => {
    const t = convexTest(schema, modules)
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all).toEqual([])
    expect(book.canon).toEqual([])
  })

  test("your own dish counts for you straight away, and for others at three", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "TT", dish: "Pastelle" })

    expect((await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })).canon)
      .toContain("Pastelle")
    expect((await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "TT" })).canon)
      .not.toContain("Pastelle")

    await t.withIdentity(you).mutation(api.health.cuisine.suggest, { country: "TT", dish: "pastelle" })
    await t.withIdentity(them).mutation(api.health.cuisine.suggest, { country: "TT", dish: "Pastelle " })

    expect((await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "TT" })).canon)
      .toContain("Pastelle")
  })

  test("a written-down dish somebody also names is listed once", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "TT", dish: "doubles" })

    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.all.filter((d) => d.key === "doubles")).toHaveLength(1)
    expect(book.canon.filter((d) => d.toLowerCase() === "doubles")).toHaveLength(1)
  })
})

describe("saying a dish is not eaten here", () => {
  test("removes an unvouched dish", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Mapopo candy" })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })

    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all.map((d) => d.dish)).not.toContain("Mapopo candy")
  })

  test("cannot remove a written-down dish", async () => {
    const t = convexTest(schema, modules)
    await expect(
      t.withIdentity(me).mutation(api.health.cuisine.reject, { country: "TT", dish: "Doubles" }),
    ).rejects.toThrow(/written list/)
  })

  test("cannot remove a dish enough people have named", async () => {
    const t = convexTest(schema, modules)
    for (const who of [me, you, them]) {
      await t.withIdentity(who).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Sadza" })
    }
    await expect(
      t.withIdentity(me).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Sadza" }),
    ).rejects.toThrow(/Enough people/)
  })
})
