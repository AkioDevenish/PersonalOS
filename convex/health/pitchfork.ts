"use node"
import Anthropic from "@anthropic-ai/sdk"
import { v } from "convex/values"
import { action } from "../_generated/server"
import { internal } from "../_generated/api"
import { userIdOf } from "../lib/me"
import { METRIC_KEYS } from "./metrics"
import { MAX_DAYS } from "./pitchforkData"
import { geminiAllowed, geminiReply } from "./pitchforkGemini"

/**
 * Pitchfork's replies, written by Claude. It gets the conversation, a short note of today's
 * numbers from the phone, and a tool that reads the person's own synced health history. Nothing
 * is stored here except a count of messages per day; the chat itself lives on the phone.
 *
 * On the dev deployment only, PITCHFORK_PROVIDER=gemini (with GEMINI_API_KEY) answers with
 * Google's Gemini free tier instead, for cheap testing. See pitchforkGemini.ts.
 */

/** The longest conversation sent in one go. Older lines drop off the front. */
const MAX_LINES = 40
/** Longer than any typed message, and long enough for text read off a photo. */
const MAX_CHARS = 8_000
/** Tool rounds before Pitchfork has to answer with what it has. */
const MAX_ROUNDS = 5

const SYSTEM = `Your name is Pitchfork. You are a friendly personal assistant inside a food and health app called Forklore. Talk like a helpful friend: short, warm, plain sentences. No lists unless asked. No long dashes. No markdown. Your replies may be read aloud. If the message includes text from a photo, such as a recipe or a food label, use it to answer.

You help with what to eat, cooking, groceries, and making sense of the person's own health numbers. When a question touches their sleep, activity, heart, weight, glucose or similar, look it up with health_history rather than guessing, and say plainly when there is no data. Only mention numbers you were given or looked up.

Never diagnose anything or mention medication. If something sounds medical or worrying, suggest they talk to a nutritionist in the app or see a doctor.`

const TOOLS: Anthropic.Beta.BetaTool[] = [
  {
    name: "health_history",
    description:
      "The person's own synced health data: one value per day for one metric, oldest first, " +
      "in the metric's canonical unit (sleep in minutes, distance in metres, energy in kcal). " +
      "Call it once per metric; several calls can run at once.",
    strict: true,
    input_schema: {
      type: "object",
      properties: {
        metric: { type: "string", enum: [...METRIC_KEYS] },
        days: { type: "integer", description: `How many days back, 1 to ${MAX_DAYS}.` },
      },
      required: ["metric", "days"],
      additionalProperties: false,
    },
  },
]

const SORRY = "Sorry, I lost my train of thought. Could you ask that again?"

/** How a lookup reads in the "thinking" steps on the phone. */
function label(metric: string, days: number): string {
  const name = metric.replace(/_/g, " ")
  return days <= 1 ? `Checked your ${name} today` : `Looked at your ${name} over ${days} days`
}

export const reply = action({
  args: {
    lines: v.array(v.object({ who: v.union(v.literal("you"), v.literal("assistant")), text: v.string() })),
    /** Today's numbers and where they cook, as the phone summarised them. */
    context: v.string(),
  },
  returns: v.object({ text: v.string(), looked: v.array(v.string()) }),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    const userId = userIdOf(identity)

    const lines = args.lines
      .slice(-MAX_LINES)
      .map((l) => ({ ...l, text: l.text.slice(0, MAX_CHARS).trim() }))
      .filter((l) => l.text.length > 0)
    // The API wants the conversation to open with the person.
    while (lines.length > 0 && lines[0].who !== "you") lines.shift()
    if (lines.length === 0 || lines[lines.length - 1].who !== "you") {
      throw new Error("Nothing to answer")
    }

    const now = Date.now()
    const allowance = await ctx.runMutation(internal.health.pitchforkData.take, {
      userId,
      day: new Date(now).toISOString().slice(0, 10),
    })
    if (!allowance.ok) {
      return { text: "That's all I can do for today. Let's pick this up again tomorrow.", looked: [] }
    }

    const system = `${SYSTEM}\n\nWhat the phone knows about them today:\n${args.context.slice(0, MAX_CHARS)}`
    const looked: string[] = []

    /** One health_history call, always for the person asking, as text for the model. */
    const lookup = async (metric: string, days: number): Promise<string> => {
      const series = await ctx.runQuery(internal.health.pitchforkData.history, { userId, metric, days, now })
      looked.push(label(metric, Math.min(MAX_DAYS, Math.max(1, Math.round(days)))))
      return series.days.length > 0 ? JSON.stringify(series) : `No ${metric} data in that time.`
    }

    if (process.env.PITCHFORK_PROVIDER === "gemini") {
      if (geminiAllowed(process.env.CONVEX_CLOUD_URL) && process.env.GEMINI_API_KEY) {
        const text = await geminiReply({
          apiKey: process.env.GEMINI_API_KEY,
          model: process.env.GEMINI_MODEL || "gemini-2.5-flash",
          system,
          lines,
          metrics: METRIC_KEYS,
          maxDays: MAX_DAYS,
          maxRounds: MAX_ROUNDS,
          lookup,
        })
        return { text: text || SORRY, looked }
      }
      console.warn("PITCHFORK_PROVIDER=gemini ignored: only allowed on dev, with GEMINI_API_KEY set")
    }

    const messages: Anthropic.Beta.BetaMessageParam[] = lines.map((l) => ({
      role: l.who === "you" ? "user" : "assistant",
      content: l.text,
    }))
    const client = new Anthropic()

    for (let round = 0; round <= MAX_ROUNDS; round++) {
      const response = await client.beta.messages.create({
        model: "claude-opus-5-5",
        max_tokens: 16000,
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: { effort: "low" },
        system,
        tools: TOOLS,
        // On the last round it has to answer with what it already found.
        tool_choice: { type: round < MAX_ROUNDS ? "auto" : "none" },
        messages,
      })

      if (response.stop_reason === "refusal") {
        return {
          text: "I can't help with that one. A nutritionist in the app or your doctor would be the right person to ask.",
          looked,
        }
      }

      if (response.stop_reason !== "tool_use") {
        const text = response.content
          .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
          .map((b) => b.text)
          .join("\n")
          .trim()
        return { text: text || SORRY, looked }
      }

      // The whole reply goes back, thinking included, so the next round carries on from it.
      messages.push({ role: "assistant", content: response.content })

      const calls = response.content.filter(
        (b): b is Anthropic.Beta.BetaToolUseBlock => b.type === "tool_use",
      )
      const results = await Promise.all(
        calls.map(async (call): Promise<Anthropic.Beta.BetaToolResultBlockParam> => {
          const input = call.input as { metric?: unknown; days?: unknown }
          if (call.name !== "health_history" || typeof input.metric !== "string" || typeof input.days !== "number") {
            return { type: "tool_result", tool_use_id: call.id, content: "Unknown tool or bad input", is_error: true }
          }
          try {
            return { type: "tool_result", tool_use_id: call.id, content: await lookup(input.metric, input.days) }
          } catch (error) {
            return { type: "tool_result", tool_use_id: call.id, content: String(error), is_error: true }
          }
        }),
      )
      // Every result in one message, so parallel lookups stay parallel.
      messages.push({ role: "user", content: results })
    }

    return { text: SORRY, looked }
  },
})
