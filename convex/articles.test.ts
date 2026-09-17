/// <reference types="vite/client" />
import { convexTest } from "convex-test"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import { api, internal } from "./_generated/api"
import schema from "./schema"
import { check } from "./articleRules"

const modules = import.meta.glob("./**/*.ts")

const REVIEWER = { subject: "user_reviewer", tokenIdentifier: "clerk|user_reviewer" }
const AUTHOR = { subject: "user_author", tokenIdentifier: "clerk|user_author" }
const STRANGER = { subject: "user_stranger", tokenIdentifier: "clerk|user_stranger" }
/** On the practitioner-approval staff list, but not the article team. */
const STAFF = { subject: "user_staff", tokenIdentifier: "clerk|user_staff" }
const DAY = 24 * 60 * 60 * 1000

const paragraph =
  "Sleep and recovery shape how the next day feels, and the pattern across a week matters more than any single night. " +
  "Going to bed and getting up at similar times helps the body know when to wind down, and it tends to make the same hours feel more restful."

const good = {
  title: "Why regular sleep timing helps",
  category: "Sleep & recovery",
  summary: "Consistent bed and wake times make the same number of hours feel more restful.",
  body: [paragraph, paragraph, paragraph].join("\n\n"),
  symbol: "moon.stars",
  colour: "2F4A7A",
}

beforeEach(() => {
  vi.stubEnv("ARTICLE_REVIEWER_IDS", REVIEWER.subject)
  vi.stubEnv("NUTRITIONIST_IDS", STAFF.subject)
  vi.useFakeTimers()
  vi.setSystemTime(new Date("2026-09-17T12:00:00Z"))
})
afterEach(() => {
  vi.unstubAllEnvs()
  vi.useRealTimers()
})

async function setup() {
  const t = convexTest(schema, modules)
  await t.run(async (ctx) => {
    await ctx.db.insert("nutritionists", {
      userId: AUTHOR.subject, name: "Dr Author", country: "TT", credentials: "RD",
      bio: "", price_credits: 0, active: true, status: "approved", updated_at: 0,
    })
    // The reviewer is a practitioner too, so the self-review rule can be tested.
    await ctx.db.insert("nutritionists", {
      userId: REVIEWER.subject, name: "Dr Reviewer", country: "TT", credentials: "MD",
      bio: "", price_credits: 0, active: true, status: "approved", updated_at: 0,
    })
    await ctx.db.insert("nutritionists", {
      userId: STRANGER.subject, name: "Pending Person", country: "TT", credentials: "Says RD",
      bio: "", price_credits: 0, active: true, status: "pending", updated_at: 0,
    })
  })
  return t
}

/** Writes, submits and verifies an article, returning its id. */
async function verified(t: Awaited<ReturnType<typeof setup>>, title = good.title) {
  const { id } = await t.withIdentity(AUTHOR).mutation(api.articles.save, { ...good, title })
  await t.withIdentity(AUTHOR).mutation(api.articles.submit, { id })
  await t.withIdentity(REVIEWER).mutation(api.articles.review, { id, approve: true })
  return id
}

/** Stands in for a purchase Apple has signed and articlePayments.ts has checked. */
async function pay(t: Awaited<ReturnType<typeof setup>>, id: any, transactionId: string, who = AUTHOR) {
  const { token } = await t.withIdentity(AUTHOR).mutation(api.articles.startPayment, { id })
  return await t.mutation(internal.articles.applyPlacement, {
    authorToken: who.tokenIdentifier,
    paymentToken: token,
    transactionId,
    productId: "os.personal.article.30days",
  })
}

describe("automatic checks", () => {
  test("a well-formed article has no errors", () => {
    expect(check(good).errors).toEqual([])
  })

  test("links, emails and phone numbers are refused", () => {
    expect(check({ ...good, summary: good.summary + " See www.example.com" }).errors)
      .toContain("Links are not allowed in articles")
    expect(check({ ...good, summary: good.summary + " Write to me@clinic.org" }).errors)
      .toContain("Email addresses are not allowed in articles")
    expect(check({ ...good, summary: good.summary + " Call +1 868 555 0199" }).errors)
      .toContain("Phone numbers are not allowed in articles")
  })

  test("a year range is not mistaken for a phone number", () => {
    expect(check({ ...good, summary: good.summary + " Studies from 2019 - 2023." }).errors).toEqual([])
  })

  test("too short, wrong category and unknown picture are refused", () => {
    const errors = check({ ...good, body: "Short.", category: "Crypto", symbol: "flame" }).errors
    expect(errors.some((e) => e.startsWith("Write at least"))).toBe(true)
    expect(errors).toContain("Choose one of the listed categories")
    expect(errors).toContain("Choose one of the listed pictures")
  })

  test("risky language is flagged for the reviewer, not blocked", () => {
    const findings = check({ ...good, body: good.body + "\n\nThis detox is guaranteed to cure it. Take 500 mg." })
    expect(findings.errors).toEqual([])
    expect(findings.flags).toEqual(expect.arrayContaining([
      "Uses the word cure", "Makes an absolute promise", "Uses wellness-marketing language", "Mentions a dose",
    ]))
  })
})

describe("who may do what", () => {
  test("someone who is not an approved practitioner cannot write", async () => {
    const t = await setup()
    await expect(t.withIdentity(STRANGER).mutation(api.articles.save, good))
      .rejects.toThrow("Only approved practitioners can write articles")
  })

  test("being on the practitioner staff list is not enough to write or to review", async () => {
    const t = await setup()
    await expect(t.withIdentity(STAFF).mutation(api.articles.save, good))
      .rejects.toThrow("Only approved practitioners can write articles")
    const { id } = await t.withIdentity(AUTHOR).mutation(api.articles.save, good)
    await t.withIdentity(AUTHOR).mutation(api.articles.submit, { id })
    await expect(t.withIdentity(STAFF).mutation(api.articles.review, { id, approve: true }))
      .rejects.toThrow("Not allowed")
  })

  test("a signed-out request cannot read the review queue", async () => {
    const t = await setup()
    await expect(t.query(api.articles.queue, {})).rejects.toThrow("Not authenticated")
    await expect(t.withIdentity(AUTHOR).query(api.articles.queue, {})).rejects.toThrow("Not allowed")
  })

  test("an author cannot edit or withdraw someone else's article", async () => {
    const t = await setup()
    const { id } = await t.withIdentity(AUTHOR).mutation(api.articles.save, good)
    await expect(t.withIdentity(REVIEWER).mutation(api.articles.save, { id, ...good, title: "Hijacked title here" }))
      .rejects.toThrow("No such article")
    await expect(t.withIdentity(STRANGER).mutation(api.articles.withdraw, { id }))
      .rejects.toThrow("No such article")
  })

  test("a reviewer cannot approve their own article", async () => {
    const t = await setup()
    const reviewer = t.withIdentity(REVIEWER)
    const { id } = await reviewer.mutation(api.articles.save, good)
    await reviewer.mutation(api.articles.submit, { id })
    await expect(reviewer.mutation(api.articles.review, { id, approve: true }))
      .rejects.toThrow("Someone else has to review your own article")
  })
})

describe("the path to Home", () => {
  test("verified is not published: nothing is on Home until it is paid for", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)

    const { id } = await author.mutation(api.articles.save, good)
    await author.mutation(api.articles.submit, { id })
    expect(await t.withIdentity(REVIEWER).query(api.articles.queue, {})).toHaveLength(1)

    await t.withIdentity(REVIEWER).mutation(api.articles.review, { id, approve: true })
    expect((await author.query(api.articles.mine, {}))[0].status).toBe("approved")
    expect(await t.query(api.articles.published, {})).toHaveLength(0)

    const result = await pay(t, id, "tx_1")
    expect(result.applied).toBe(true)
    expect(result.live_until).toBe(Date.now() + 30 * DAY)

    const live = await t.query(api.articles.published, {})
    expect(live).toHaveLength(1)
    expect(live[0]).toMatchObject({ title: good.title, author: "Dr Author", credentials: "RD" })
    expect(live[0].body).toHaveLength(3)
  })

  test("an article cannot be paid for before the team verifies it", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    const { id } = await author.mutation(api.articles.save, good)
    await expect(author.mutation(api.articles.startPayment, { id })).rejects.toThrow("once the team has verified it")
    await author.mutation(api.articles.submit, { id })
    await expect(author.mutation(api.articles.startPayment, { id })).rejects.toThrow("once the team has verified it")
  })

  test("a purchase only counts for the author who made it", async () => {
    const t = await setup()
    const id = await verified(t)
    await expect(pay(t, id, "tx_1", STRANGER)).rejects.toThrow("not for one of your articles")
    expect(await t.query(api.articles.published, {})).toHaveLength(0)
  })

  test("the same transaction redelivered is applied once", async () => {
    const t = await setup()
    const id = await verified(t)
    const first = await pay(t, id, "tx_1")
    const again = await pay(t, id, "tx_1")
    expect(again.applied).toBe(false)
    expect(again.live_until).toBe(first.live_until)
  })

  test("renewing early adds thirty days to the end rather than restarting", async () => {
    const t = await setup()
    const id = await verified(t)
    const first = await pay(t, id, "tx_1")
    vi.setSystemTime(Date.now() + 10 * DAY)
    const second = await pay(t, id, "tx_2")
    expect(second.live_until).toBe(first.live_until + 30 * DAY)
  })

  test("it comes off Home when the time runs out, and a renewal puts it back", async () => {
    const t = await setup()
    const id = await verified(t)
    await pay(t, id, "tx_1")

    vi.setSystemTime(Date.now() + 29 * DAY)
    await t.mutation(internal.articles.expire, { id })
    expect(await t.query(api.articles.published, {})).toHaveLength(1)

    vi.setSystemTime(Date.now() + 2 * DAY)
    await t.mutation(internal.articles.expire, { id })
    expect(await t.query(api.articles.published, {})).toHaveLength(0)
    expect((await t.withIdentity(AUTHOR).query(api.articles.mine, {}))[0].status).toBe("expired")

    await pay(t, id, "tx_2")
    expect(await t.query(api.articles.published, {})).toHaveLength(1)
  })

  test("a draft that fails the checks cannot be submitted", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    const { id, errors } = await author.mutation(api.articles.save, { ...good, body: "Too short to publish." })
    expect(errors.length).toBeGreaterThan(0)
    await expect(author.mutation(api.articles.submit, { id })).rejects.toThrow("Write at least")
  })

  test("sending back needs a note, and the note reaches the author", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    const reviewer = t.withIdentity(REVIEWER)
    const { id } = await author.mutation(api.articles.save, good)
    await author.mutation(api.articles.submit, { id })

    await expect(reviewer.mutation(api.articles.review, { id, approve: false }))
      .rejects.toThrow("Say what needs changing")
    await reviewer.mutation(api.articles.review, { id, approve: false, note: "Please cite where seven hours comes from." })

    const [mineRow] = await author.query(api.articles.mine, {})
    expect(mineRow.status).toBe("changes_requested")
    expect(mineRow.review_note).toBe("Please cite where seven hours comes from.")
  })

  test("an edit comes off Home, and re-verification puts it back for the time already paid", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    const id = await verified(t)
    await pay(t, id, "tx_1")

    await author.mutation(api.articles.save, { id, ...good, title: "Why regular sleep timing helps you" })
    expect(await t.query(api.articles.published, {})).toHaveLength(0)

    await author.mutation(api.articles.submit, { id })
    await t.withIdentity(REVIEWER).mutation(api.articles.review, { id, approve: true })
    expect(await t.query(api.articles.published, {})).toHaveLength(1)
  })

  test("withdrawing removes it from Home and gives up the time left", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    const id = await verified(t)
    await pay(t, id, "tx_1")
    await author.mutation(api.articles.withdraw, { id })
    expect(await t.query(api.articles.published, {})).toHaveLength(0)
    expect((await author.query(api.articles.mine, {}))[0].live_until).toBeNull()
  })

  test("an author can have at most three articles waiting", async () => {
    const t = await setup()
    const author = t.withIdentity(AUTHOR)
    for (let i = 0; i < 3; i++) {
      const { id } = await author.mutation(api.articles.save, { ...good, title: `${good.title} ${i}` })
      await author.mutation(api.articles.submit, { id })
    }
    const { id } = await author.mutation(api.articles.save, { ...good, title: `${good.title} 4` })
    await expect(author.mutation(api.articles.submit, { id })).rejects.toThrow("three articles waiting")
  })
})
