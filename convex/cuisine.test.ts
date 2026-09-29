/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import schema from "./schema"
import { CURATED, curatedFor } from "./health/dishes"
import { grounded } from "./health/cuisineSource"

const modules = import.meta.glob("./**/*.ts")
afterEach(() => vi.unstubAllEnvs())

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
  test("hides the dish for the person who said so", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Mapopo candy" })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })

    const yours = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(yours.all.map((d) => d.dish)).not.toContain("Mapopo candy")
  })

  test("does not take the dish off anyone else's list", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Mapopo candy" })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })

    const mine = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(mine.all.map((d) => d.dish)).toContain("Mapopo candy")
    expect(mine.canon).toContain("Mapopo candy")
  })

  test("saying it again brings the dish back", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Mapopo candy" })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })

    const yours = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(yours.all.map((d) => d.dish)).toContain("Mapopo candy")
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

describe("the generated list", () => {
  test("only keeps dishes the article actually names", () => {
    const article = "Popular foods include doubles, roti and pelau. Callaloo is eaten on Sundays."
    expect(grounded(["Doubles", "Roti", "Bunny chow", "Pelau", "Ackee and saltfish"], article))
      .toEqual(["Doubles", "Roti", "Pelau"])
  })

  test("drops repeats and variations of one dish", () => {
    const article = "caldo verde, caldo verde de peixe and funge are common"
    expect(grounded(["Caldo verde", "Caldo verde de peixe", "caldo verde", "Funge"], article))
      .toEqual(["Caldo verde", "Funge"])
  })

  test("matches accented names against unaccented text", () => {
    expect(grounded(["Phở"], "pho is a noodle soup")).toEqual(["Phở"])
  })

  test("replaces the written list once it exists", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.health.cuisine.saveGenerated, {
      country: "TT", dishes: ["Doubles", "Pelau", "Kurma"], source: "Trinidad and Tobago cuisine",
    })
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.canon.sort()).toEqual(["Doubles", "Kurma", "Pelau"])
  })

  test("a generated dish can be rejected, for the one who rejects it", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.health.cuisine.saveGenerated, { country: "TT", dishes: ["Doubles", "Kurma"] })
    await t.withIdentity(me).mutation(api.health.cuisine.reject, { country: "TT", dish: "Kurma" })
    const mine = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(mine.canon).toEqual(["Doubles"])
    const yours = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(yours.canon.sort()).toEqual(["Doubles", "Kurma"])
  })

  test("prepare starts one generation and reports it", async () => {
    const t = convexTest(schema, modules)
    vi.stubEnv("ANTHROPIC_API_KEY", "test")
    expect((await t.withIdentity(me).mutation(api.health.cuisine.prepare, { country: "ZW" })).started).toBe(true)
    expect((await t.withIdentity(you).mutation(api.health.cuisine.prepare, { country: "ZW" })).started).toBe(false)
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.generating).toBe(true)
  })

  test("an empty result counts as failed and keeps the written list", async () => {
    const t = convexTest(schema, modules)
    await t.mutation(internal.health.cuisine.saveGenerated, { country: "TT", dishes: [] })
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.canon).toContain("Doubles")
    expect(book.generating).toBe(false)
  })

  test("prepare refuses anything that isn't a country code", async () => {
    const t = convexTest(schema, modules)
    await expect(t.withIdentity(me).mutation(api.health.cuisine.prepare, { country: "zz; drop" }))
      .rejects.toThrow(/country code/)
  })
})
