/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { describe, expect, test } from "vitest"
import { api } from "./_generated/api"
import schema from "./schema"
import { CURATED, curatedFor } from "./health/dishes"
import { sift } from "./health/cuisine"

const modules = import.meta.glob("./**/*.ts")

const me = { subject: "user_1|session_a", tokenIdentifier: "https://x|user_1|session_a" }
const you = { subject: "user_2|session_b", tokenIdentifier: "https://x|user_2|session_b" }
const them = { subject: "user_3|session_c", tokenIdentifier: "https://x|user_3|session_c" }

describe("the written-down dishes", () => {
  test("no country repeats a dish, and none are variations of each other", () => {
    for (const [country, dishes] of Object.entries(CURATED)) {
      const keys = dishes.map((d) => d.trim().toLowerCase())
      expect(new Set(keys).size, `${country} repeats a dish`).toBe(keys.length)

      // The failure that produced the Angolan list was one dish padded out
      // with proteins: caldo verde, caldo verde de peixe, caldo verde de
      // frango. Any dish whose whole name is the start of another's is that
      // shape, and is worth looking at rather than shipping.
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

  test("Trinidad has the food Trinidad eats, and not its neighbours'", () => {
    const tt = curatedFor("TT").map((d) => d.toLowerCase())
    for (const dish of ["doubles", "roti", "pelau", "callaloo", "bake and shark"]) {
      expect(tt, `TT is missing ${dish}`).toContain(dish)
    }
    // What the model put there instead.
    for (const wrong of ["ackee and saltfish", "rice and peas", "bunny chow", "fish and chips"]) {
      expect(tt, `TT should not claim ${wrong}`).not.toContain(wrong)
    }
  })
})

describe("what the prompt is allowed to cook from", () => {
  test("a written-down country needs no votes at all", async () => {
    const t = convexTest(schema, modules)
    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.canon).toContain("Doubles")
    expect(book.canon.length).toBe(curatedFor("TT").length)
  })

  test("and refuses a guessed list even when the phone offers one", async () => {
    const t = convexTest(schema, modules)
    const result = await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "TT",
      dishes: ["Ackee and saltfish", "Bunny chow", "Fish and chips"],
    })
    expect(result.seeded).toBe(0)

    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(book.canon).not.toContain("Bunny chow")
  })

  test("a country nobody has written down still gets seeded", async () => {
    const t = convexTest(schema, modules)
    const result = await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "ZZ",
      dishes: ["Something local", "Something else local"],
    })
    expect(result.seeded).toBe(2)
  })

  test("your own suggestion counts for you straight away, and for others at three", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "TT", dish: "Pastelle" })

    const mine = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(mine.canon).toContain("Pastelle")

    const yours = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(yours.canon).not.toContain("Pastelle")

    await t.withIdentity(you).mutation(api.health.cuisine.suggest, { country: "TT", dish: "pastelle" })
    await t.withIdentity(them).mutation(api.health.cuisine.suggest, { country: "TT", dish: "Pastelle " })

    const everyone = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "TT" })
    expect(everyone.canon).toContain("Pastelle")
  })

  test("a written-down dish somebody also names is not listed twice", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.suggest, { country: "TT", dish: "doubles" })

    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "TT" })
    const doubles = book.all.filter((d) => d.key === "doubles")
    expect(doubles).toHaveLength(1)
    expect(book.canon.filter((d) => d.toLowerCase() === "doubles")).toHaveLength(1)
  })
})

describe("what a model is allowed to put on the list", () => {
  test("the Angola list is refused entirely", async () => {
    // Exactly what was in the database: two dishes, neither Angolan, padded
    // out with proteins until there were ten.
    const angola = [
      "Caldo Verde", "Caldo Verde de Peixe", "Caldo Verde de Frango",
      "Caldo Verde de Bacalhau", "Caldo Verde de Marisco",
      "Moqueca", "Moqueca de Peixe", "Moqueca de Frango",
      "Moqueca de Bacalhau", "Moqueca de Marisco",
    ]
    expect(sift(angola)).toEqual([])
  })

  test("ingredients and cooking methods are not dishes", () => {
    expect(sift(["Curry", "Fried Chicken", "Boiled Beans", "Fried Fish"])).toEqual([])
  })

  test("a real list passes through untouched", () => {
    const real = ["Ugali", "Sukuma wiki", "Nyama choma", "Githeri", "Chapati", "Pilau"]
    expect(sift(real)).toEqual(real)
  })

  test("and a country nobody wrote down only keeps what survives the sieve", async () => {
    const t = convexTest(schema, modules)
    const result = await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "ZW",
      dishes: ["Sadza", "Sadza ne nyama", "Muriwo", "Curry", "Mapopo candy", "Bota"],
    })
    // "Sadza ne nyama" is a variation of "Sadza"; "Curry" is not a dish.
    expect(result.seeded).toBe(4)
  })
})

describe("a guessed dish", () => {
  test("is offered for confirmation, not fed to the prompt", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "ZW",
      dishes: ["Sadza", "Muriwo", "Bota", "Mapopo candy"],
    })

    const book = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all.map((d) => d.dish)).toContain("Sadza")
    expect(book.canon).toEqual([])
  })

  test("enters the prompt once people confirm it", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "ZW",
      dishes: ["Sadza", "Muriwo", "Bota", "Mapopo candy"],
    })
    for (const who of [me, you, them]) {
      await t.withIdentity(who).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Sadza" })
    }

    const book = await t.withIdentity(you).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.canon).toEqual(["Sadza"])
  })

  test("and can be taken off the list by one person who knows better", async () => {
    const t = convexTest(schema, modules)
    await t.withIdentity(me).mutation(api.health.cuisine.seed, {
      country: "ZW",
      dishes: ["Sadza", "Muriwo", "Bota", "Mapopo candy"],
    })
    await t.withIdentity(you).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Mapopo candy" })

    const book = await t.withIdentity(me).query(api.health.cuisine.forCountry, { country: "ZW" })
    expect(book.all.map((d) => d.dish)).not.toContain("Mapopo candy")
  })
})

describe("what cannot be taken off the list", () => {
  test("a written-down dish", async () => {
    const t = convexTest(schema, modules)
    await expect(
      t.withIdentity(me).mutation(api.health.cuisine.reject, { country: "TT", dish: "Doubles" })
    ).rejects.toThrow(/written list/)
  })

  test("a dish enough people have named", async () => {
    const t = convexTest(schema, modules)
    for (const who of [me, you, them]) {
      await t.withIdentity(who).mutation(api.health.cuisine.suggest, { country: "ZW", dish: "Sadza" })
    }
    await expect(
      t.withIdentity(me).mutation(api.health.cuisine.reject, { country: "ZW", dish: "Sadza" })
    ).rejects.toThrow(/Enough people/)
  })
})
