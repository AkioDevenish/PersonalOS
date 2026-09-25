/**
 * The privacy policy and the terms, as pages.
 *
 * Google will not publish an OAuth consent screen without a privacy policy at
 * a real address; Meta will not accept an app without one; Apple will not take
 * a submission without one. All three want a URL, not a PDF, and the URL has
 * to keep working. This app has no web server any more, so they are served
 * from the same deployment that serves the app — one less thing that can be
 * true today and gone next year.
 *
 * Everything below describes what the code does. Where a claim is unusual —
 * cycle data never leaving the phone, readings never reaching an AI company —
 * it is unusual because of a decision in the code, and the decision is named
 * so that changing it means changing this too.
 */

const UPDATED = "24 September 2026"
const CONTACT = "akiodevenish1@gmail.com"

/** One shell for both pages: readable, adapts to dark mode, no dependencies. */
function page(title: string, body: string): Response {
  return new Response(
    `<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Personal OS</title>
<style>
  :root { color-scheme: light dark; --ink: #17181a; --dim: #6b6f76; --rule: #e3e4e7; --bg: #fdfdfd }
  @media (prefers-color-scheme: dark) {
    :root { --ink: #ecedef; --dim: #9a9ea6; --rule: #2a2c30; --bg: #121315 }
  }
  * { box-sizing: border-box }
  body { margin: 0; background: var(--bg); color: var(--ink);
         font: 17px/1.65 -apple-system, system-ui, "Segoe UI", sans-serif;
         -webkit-text-size-adjust: 100% }
  main { max-width: 38rem; margin: 0 auto; padding: 56px 20px 96px }
  h1 { font-size: 1.75rem; font-weight: 600; letter-spacing: -.02em; margin: 0 0 .25rem }
  h2 { font-size: 1.05rem; font-weight: 600; margin: 2.4rem 0 .6rem }
  .updated { color: var(--dim); font-size: .9rem; margin: 0 0 2.5rem }
  p, li { margin: 0 0 .9rem }
  ul { padding-left: 1.2rem; margin: 0 0 1rem }
  strong { font-weight: 600 }
  a { color: inherit }
  hr { border: 0; border-top: 1px solid var(--rule); margin: 3rem 0 1.5rem }
  footer { color: var(--dim); font-size: .9rem }
</style>
<main>
<h1>${title}</h1>
<p class="updated">Last updated ${UPDATED}</p>
${body}
<hr>
<footer>Questions about any of this: <a href="mailto:${CONTACT}">${CONTACT}</a></footer>
</main>`,
    {
      status: 200,
      headers: {
        "content-type": "text/html; charset=utf-8",
        // These are read by Google, Meta and Apple as much as by people, and
        // they are not secret. A day of caching keeps a review bot from
        // hammering the deployment without making an edit take a week.
        "cache-control": "public, max-age=86400",
      },
    },
  )
}

export const privacy = () =>
  page(
    "Privacy",
    `
<p>Personal OS records health information, which is about as personal as data gets. This page says plainly what is kept, where it is kept, and who else can see it. It describes how the app actually works rather than what we might one day like to do.</p>

<h2>What stays on your phone and is never sent anywhere</h2>
<ul>
  <li><strong>Cycle tracking.</strong> Periods, symptoms and predicted phases are stored on your device only. They are deliberately excluded from everything the app uploads, so they are not on our servers, not in any backup of ours, and not visible to any practitioner. Deleting the app deletes them.</li>
  <li><strong>Your AI readings are written on your phone.</strong> They are produced by Apple's on-device model, which runs locally. Your health data is not sent to OpenAI, Anthropic, Google or any other AI provider — not for generating readings, and not for training anything.</li>
</ul>

<h2>What is stored on our servers</h2>
<ul>
  <li><strong>Your account.</strong> Email address, the name you choose, and a hashed password — the password itself is never stored. If you sign in with Google, Facebook or Apple instead, we receive your email address and name from them and nothing else.</li>
  <li><strong>Health measurements you choose to sync.</strong> Steps, distance, heart rate, sleep and similar readings from Apple Health, each with a timestamp and the name of the device that recorded it.</li>
  <li><strong>Consultations.</strong> If you consult a practitioner, the topic, the messages, and what you explicitly chose to share with them.</li>
  <li><strong>Purchases.</strong> Whether a subscription is active, and Apple's signed receipt for it.</li>
  <li><strong>Notification tokens</strong>, if you allow notifications, so a finished reading can reach your phone.</li>
</ul>

<h2>Who else sees it</h2>
<p>Nobody, except in these specific cases:</p>
<ul>
  <li><strong>A practitioner you consult</strong> sees what you chose to share with them when you booked, and the messages you send them. Nothing else.</li>
  <li><strong>Stripe</strong> handles payments for consultations and article placement. Card details are entered on Stripe's own pages and never reach our servers.</li>
  <li><strong>Apple</strong> handles subscriptions and delivers notifications.</li>
  <li><strong>Convex</strong> hosts the database and the servers.</li>
</ul>
<p>We do not sell data, we do not share it with advertisers, and there are no analytics or tracking services in the app.</p>

<h2>Deleting your account</h2>
<p>You can delete your account from inside the app, under your profile. Doing so removes your sign-in and then deletes your health measurements, readings, consultations, messages, receipts and notification tokens from our database. It is not a flag on a row that stays; the rows go.</p>
<p>One exception: if you are a practitioner and have published articles, those remain, because readers have paid to read them. Ask us if you want them taken down.</p>

<h2>Children</h2>
<p>Personal OS is not intended for anyone under 16, and accounts are not knowingly created for them.</p>

<h2>Changes</h2>
<p>If this page changes in a way that affects what is collected or who sees it, the app will say so rather than quietly updating the date at the top.</p>
`,
  )

export const terms = () =>
  page(
    "Terms",
    `
<h2>What this app is</h2>
<p>Personal OS shows you your own health data, lets you set goals, and lets you consult independent practitioners and read articles they write.</p>

<h2>What it is not</h2>
<p><strong>Nothing in Personal OS is medical advice.</strong> The readings are generated by software from numbers your phone recorded; they can be wrong, and they do not know anything about you beyond those numbers. Articles are written by individual practitioners and represent their views. If something about your health worries you, speak to a doctor. Do not delay doing so because of anything this app showed you.</p>

<h2>Practitioners</h2>
<p>Practitioners on Personal OS are independent. They are not our employees and we do not supervise their advice. We check that a practitioner is who they say they are and that an article meets our standards before it is published, but the responsibility for what they tell you is theirs.</p>
<p>We take a 15% commission on consultations and paid article placement. Practitioners are paid through Stripe.</p>

<h2>Paying</h2>
<p>Subscriptions are billed by Apple and renew until cancelled. Cancel from your Apple account settings; we cannot cancel an Apple subscription for you. Refunds for subscriptions are handled by Apple.</p>
<p>Consultations and article placement are paid directly and are not refundable once the consultation has taken place or the article has gone live.</p>

<h2>Your account</h2>
<p>Keep your password to yourself. Tell us if you think somebody else has access to your account. You can delete your account at any time from inside the app.</p>

<h2>Ending it</h2>
<p>You can stop using Personal OS whenever you like. We may close an account that is used to harass somebody, to impersonate a practitioner, or to break the law.</p>

<h2>Liability</h2>
<p>Personal OS is provided as it is. We do not promise it will be uninterrupted or that every number it shows will be accurate. To the extent the law allows, we are not liable for decisions made on the basis of what the app displays. Nothing here limits liability that cannot lawfully be limited.</p>
`,
  )
