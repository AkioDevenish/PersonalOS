/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { describe, expect, test } from "vitest"
import { internal } from "./_generated/api"
import schema from "./schema"
import { DAILY_LIMIT } from "./health/pitchforkData"
import { geminiAllowed, geminiReply } from "./health/pitchforkGemini"

const modules = import.meta.glob("./**/*.ts")

const DAY = 24 * 60 * 60 * 1000
const now = Date.UTC(2026, 8, 30, 12)

function sample(userId: string, provider: string, metric: string, value: number, at: number, day: string) {
  return {
    userId, provider, metric, value, unit: metric === "steps" ? "count" : "min",
    recorded_at: at, day, ingested_at: at,
  }
}

describe("what Pitchfork can look up", () => {
  test("one value per day, oldest first, only your own", async () => {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => {
      await ctx.db.insert("health_samples", sample("me", "apple_health", "steps", 4000, now - 2 * DAY, "2026-09-28"))
      await ctx.db.insert("health_samples", sample("me", "apple_health", "steps", 1000, now - 2 * DAY + 60_000, "2026-09-28"))
      await ctx.db.insert("health_samples", sample("me", "apple_health", "steps", 7000, now - DAY, "2026-09-29"))
      await ctx.db.insert("health_samples", sample("you", "apple_health", "steps", 99999, now - DAY, "2026-09-29"))
    })

    const series = await t.query(internal.health.pitchforkData.history, {
      userId: "me", metric: "steps", days: 7, now,
    })
    expect(series.unit).toBe("count")
    expect(series.days).toEqual([
      { day: "2026-09-28", value: 5000 },
      { day: "2026-09-29", value: 7000 },
    ])
  })

  test("prefers the more trusted device when two report the same night", async () => {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => {
      await ctx.db.insert("health_samples", sample("me", "apple_health", "sleep_duration", 300, now - DAY, "2026-09-29"))
      await ctx.db.insert("health_samples", sample("me", "oura", "sleep_duration", 420, now - DAY, "2026-09-29"))
    })
    const series = await t.query(internal.health.pitchforkData.history, {
      userId: "me", metric: "sleep_duration", days: 3, now,
    })
    expect(series.days).toEqual([{ day: "2026-09-29", value: 420 }])
  })

  test("leaves out days older than asked for", async () => {
    const t = convexTest(schema, modules)
    await t.run(async (ctx) => {
      await ctx.db.insert("health_samples", sample("me", "apple_health", "steps", 3000, now - 10 * DAY, "2026-09-20"))
    })
    const series = await t.query(internal.health.pitchforkData.history, {
      userId: "me", metric: "steps", days: 7, now,
    })
    expect(series.days).toEqual([])
  })

  test("refuses a metric that doesn't exist", async () => {
    const t = convexTest(schema, modules)
    await expect(
      t.query(internal.health.pitchforkData.history, { userId: "me", metric: "mood", days: 7, now }),
    ).rejects.toThrow(/Unknown metric/)
  })
})

describe("how much one person can ask", () => {
  test("stops at the daily limit and starts again the next day", async () => {
    const t = convexTest(schema, modules)
    for (let i = 0; i < DAILY_LIMIT; i++) {
      const r = await t.mutation(internal.health.pitchforkData.take, { userId: "me", day: "2026-09-30" })
      expect(r.ok).toBe(true)
    }
    const over = await t.mutation(internal.health.pitchforkData.take, { userId: "me", day: "2026-09-30" })
    expect(over).toEqual({ ok: false, left: 0 })

    const other = await t.mutation(internal.health.pitchforkData.take, { userId: "you", day: "2026-09-30" })
    expect(other.ok).toBe(true)
    const tomorrow = await t.mutation(internal.health.pitchforkData.take, { userId: "me", day: "2026-10-01" })
    expect(tomorrow.ok).toBe(true)
  })
})

describe("Gemini, for testing on dev", () => {
  test("only the dev deployment may use it", () => {
    expect(geminiAllowed("https://wary-penguin-35.convex.cloud")).toBe(true)
    expect(geminiAllowed("https://astute-ant-253.convex.cloud")).toBe(false)
    expect(geminiAllowed("https://wary-penguin-35.convex.cloud.evil.com")).toBe(false)
    expect(geminiAllowed(undefined)).toBe(false)
    expect(geminiAllowed("not a url")).toBe(false)
  })

  test("looks things up, hands the results back, and returns the answer", async () => {
    const bodies: { contents: { role: string; parts: Record<string, unknown>[] }[] }[] = []
    const replies = [
      { candidates: [{ content: { role: "model", parts: [
        { functionCall: { name: "health_history", args: { metric: "steps", days: 7 } }, thoughtSignature: "sig" },
      ] } }] },
      { candidates: [{ content: { role: "model", parts: [
        { text: "thinking", thought: true },
        { text: "You walked a lot this week." },
      ] } }] },
    ]
    const fakeFetch = (async (_url: unknown, init?: { body?: unknown }) => {
      bodies.push(JSON.parse(String(init?.body)))
      return new Response(JSON.stringify(replies.shift()), { status: 200 })
    }) as typeof fetch
    const asked: [string, number][] = []

    const text = await geminiReply({
      apiKey: "k", model: "m", system: "s",
      lines: [{ who: "you", text: "How active was I?" }],
      metrics: ["steps"], maxDays: 90, maxRounds: 5,
      lookup: async (metric, days) => { asked.push([metric, days]); return "5000 a day" },
      fetchImpl: fakeFetch,
    })

    expect(text).toBe("You walked a lot this week.")
    expect(asked).toEqual([["steps", 7]])
    const second = bodies[1].contents
    expect(second[1]).toEqual({ role: "model", parts: [
      { functionCall: { name: "health_history", args: { metric: "steps", days: 7 } }, thoughtSignature: "sig" },
    ] })
    expect(second[2]).toEqual({ role: "user", parts: [
      { functionResponse: { name: "health_history", response: { result: "5000 a day" } } },
    ] })
  })
})
