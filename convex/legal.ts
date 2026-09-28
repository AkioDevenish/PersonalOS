/** The privacy policy and the terms, as pages. */

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
        // These are read by Google, Meta and Apple as much as by people, and they are not secret.
        "cache-control": "public, max-age=86400",
      },
    },
  )
}

export const privacy = () =>
  page(
    "Privacy",
    `
<p>Personal OS uses your health information, which is about as personal as data gets. This page explains what we keep, where we keep it, and who can see it.</p>

<h2>What stays on your phone</h2>
<ul>
  <li><strong>Meal ideas are written on your phone.</strong> Apple's own model makes them on your phone. We don't send your health data to OpenAI, Anthropic, Google or any other AI company, and we don't use it to train anything.</li>
</ul>

<h2>What is stored on our servers</h2>
<ul>
  <li><strong>Your account.</strong> Your email, the name you choose, and an encrypted version of your password. We never store the password itself. If you sign in with Google, Facebook or Apple, we only get your name and email from them.</li>
  <li><strong>Health measurements you choose to sync.</strong> Steps, heart rate, sleep and other readings from Apple Health, with the time and the device that recorded them.</li>
  <li><strong>Consultations.</strong> If you talk to a practitioner, we keep the messages and anything you chose to share.</li>
  <li><strong>Purchases.</strong> Whether a subscription is active, and Apple's signed receipt for it.</li>
  <li><strong>Notification tokens</strong>, if you allow notifications, so a practitioner's reply can reach your phone.</li>
</ul>

<h2>Who else sees it</h2>
<p>Only these people and companies:</p>
<ul>
  <li><strong>A practitioner you consult</strong> sees your messages and whatever you chose to share.</li>
  <li><strong>Stripe</strong> handles payments for consultations and article placement. You enter card details on Stripe's pages, so they never reach us.</li>
  <li><strong>Apple</strong> handles subscriptions and delivers notifications.</li>
  <li><strong>Convex</strong> hosts the database and the servers.</li>
  <li><strong>Anthropic</strong> builds each country's list of everyday dishes from Wikipedia. It gets the country name and the article, never anything about you.</li>
</ul>
<p>We don't sell your data or share it with advertisers, and the app has no tracking.</p>

<h2>Deleting your account</h2>
<p>You can delete your account from inside the app, under your profile. This deletes your login, health readings, consultations, messages, receipts and notification settings from our database for good.</p>
<p>One exception: if you are a practitioner and have published articles, those remain, because readers have paid to read them. Ask us if you want them taken down.</p>

<h2>Children</h2>
<p>Personal OS isn't meant for anyone under 16.</p>

<h2>Changes</h2>
<p>If we change what we collect or who sees it, we'll tell you in the app.</p>
`,
  )

export const terms = () =>
  page(
    "Terms",
    `
<h2>What this app is</h2>
<p>Personal OS suggests meals from your own health data, lets you consult independent practitioners, and lets you read articles they write.</p>

<h2>What it is not</h2>
<p><strong>Nothing in Personal OS is medical advice.</strong> Meal ideas come from software reading your phone's numbers, and they can be wrong. Articles are each practitioner's own view. If something about your health worries you, see a doctor, and don't wait because of anything in this app.</p>

<h2>Practitioners</h2>
<p>Practitioners on Personal OS are independent, not our employees. We check who they are and review their articles before they go up, but they're responsible for their own advice.</p>
<p>We take a 15% commission on consultations and paid article placement. Practitioners are paid through Stripe.</p>

<h2>Paying</h2>
<p>Apple bills subscriptions, and they renew until you cancel. Cancel in your Apple account settings; we can't do it for you. Apple handles subscription refunds.</p>
<p>Consultations and article placements can't be refunded once they've happened.</p>

<h2>Your account</h2>
<p>Keep your password private, and tell us if you think someone else is using your account. You can delete your account at any time from inside the app.</p>

<h2>Ending it</h2>
<p>You can stop using Personal OS whenever you like. We may close accounts used to harass people, pose as a practitioner, or break the law.</p>

<h2>Liability</h2>
<p>Personal OS is provided as is. We can't promise it will always work or that every number is right. As far as the law allows, we aren't liable for decisions you make based on the app. Nothing here limits liability that the law says can't be limited.</p>
`,
  )
