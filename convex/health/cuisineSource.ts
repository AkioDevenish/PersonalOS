import Anthropic from "@anthropic-ai/sdk"

/** Reads a country's cuisine from Wikipedia and has Claude pick its everyday dishes. */

const WIKI = "https://en.wikipedia.org/w/api.php"
const AGENT = "PersonalOS/1.0 (akiodevenish1@gmail.com)"

async function wiki(params: Record<string, string>) {
  const url = `${WIKI}?${new URLSearchParams({ format: "json", ...params })}`
  const response = await fetch(url, { headers: { "User-Agent": AGENT } })
  if (!response.ok) throw new Error(`Wikipedia ${response.status}`)
  return response.json()
}

async function extract(title: string): Promise<string> {
  const json = await wiki({ action: "query", prop: "extracts", explaintext: "1", redirects: "1", titles: title })
  const page = Object.values(json.query?.pages ?? {})[0] as { extract?: string } | undefined
  return page?.extract ?? ""
}

/** The cuisine article for a country, or its country article's cuisine section. */
export async function cuisineText(country: string): Promise<{ title: string; text: string } | null> {
  const found = await wiki({ action: "query", list: "search", srsearch: `${country} cuisine`, srlimit: "5" })
  const titles: string[] = (found.query?.search ?? []).map((r: { title: string }) => r.title)
  const cuisine = titles.find((t) => /cuisine/i.test(t) && !/list of/i.test(t))
  if (cuisine) {
    const text = await extract(cuisine)
    if (text.length > 500) return { title: cuisine, text }
  }

  const article = await extract(country)
  const section = article.match(/\n==+\s*(Cuisine|Food)[^=]*==+\n([\s\S]*?)(\n==[^=]|$)/i)
  if (section && section[2].length > 300) return { title: `${country} (cuisine section)`, text: section[2] }
  return null
}

const SYSTEM = `You pick out a country's everyday home dishes from an article about its food.

Only list dishes the article names. Prefer food people cook and eat on an ordinary day: breakfast, lunch, dinner, street food. Leave out drinks, desserts eaten only at festivals, single ingredients, and cooking methods.

Write each dish name exactly as the article spells it. List each dish once, not once per filling or meat. At most 20.`

const SCHEMA = {
  type: "object",
  properties: { dishes: { type: "array", items: { type: "string" } } },
  required: ["dishes"],
  additionalProperties: false,
} as const

function normalise(s: string) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/\s+/g, " ").trim()
}

/** Drops anything not in the source, repeats, and variations of a dish already kept. */
export function grounded(dishes: string[], source: string): string[] {
  const text = normalise(source)
  const kept: string[] = []
  for (const raw of dishes) {
    const dish = raw.trim()
    const key = normalise(dish)
    if (!key || dish.length > 60 || !text.includes(key)) continue
    if (kept.some((k) => { const o = normalise(k); return o === key || key.startsWith(o + " ") || o.startsWith(key + " ") })) continue
    kept.push(dish)
  }
  return kept
}

/** Everyday dishes for a country, every one of them named in the source article. */
export async function generateDishes(
  client: Anthropic,
  country: string,
): Promise<{ dishes: string[]; source: string | null }> {
  const source = await cuisineText(country)
  if (!source) return { dishes: [], source: null }

  const response = await client.beta.messages.create({
    model: "claude-opus-5",
    max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { effort: "medium", format: { type: "json_schema", schema: SCHEMA } },
    system: SYSTEM,
    messages: [{
      role: "user",
      content: `Country: ${country}\n\nArticle "${source.title}":\n\n${source.text}`,
    }],
  })

  if (response.stop_reason === "refusal") throw new Error("Claude declined the request")
  const text = response.content.find((b) => b.type === "text")
  if (!text || text.type !== "text") throw new Error("No answer from Claude")

  const parsed = JSON.parse(text.text) as { dishes: string[] }
  return { dishes: grounded(parsed.dishes, source.text), source: source.title }
}
