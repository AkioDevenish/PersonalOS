"use node"
import Anthropic from "@anthropic-ai/sdk"
import { v } from "convex/values"
import { internalAction } from "../_generated/server"
import { internal } from "../_generated/api"
import { generateDishes } from "./cuisineSource"
import { CURATED } from "./dishes"

function englishName(code: string) {
  return new Intl.DisplayNames(["en"], { type: "region" }).of(code) ?? code
}

/** Generates and stores a country's dish list. */
export const generate = internalAction({
  args: { country: v.string() },
  handler: async (ctx, args) => {
    try {
      const { dishes, source } = await generateDishes(new Anthropic(), englishName(args.country))
      await ctx.runMutation(internal.health.cuisine.saveGenerated, {
        country: args.country, dishes, source: source ?? undefined,
      })
    } catch (error) {
      await ctx.runMutation(internal.health.cuisine.saveGenerated, {
        country: args.country, dishes: [], error: String(error),
      })
    }
  },
})

/** Compares generated lists against the hand-written ones in dishes.ts. */
export const evaluate = internalAction({
  args: { countries: v.optional(v.array(v.string())) },
  handler: async (_ctx, args) => {
    const client = new Anthropic()
    const codes = args.countries ?? Object.keys(CURATED)
    const norm = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim()

    const rows = await Promise.all(codes.map(async (code) => {
      try {
        const { dishes, source } = await generateDishes(client, englishName(code))
        const hand = new Set((CURATED[code] ?? []).map(norm))
        const matched = dishes.filter((d) => hand.has(norm(d)))
        return {
          country: code,
          source,
          generated: dishes.length,
          alsoOnHandList: matched.length,
          notOnHandList: dishes.filter((d) => !hand.has(norm(d))),
        }
      } catch (error) {
        return { country: code, error: String(error) }
      }
    }))
    return rows
  },
})
