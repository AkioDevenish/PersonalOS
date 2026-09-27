import { httpRouter } from "convex/server"
import { httpAction } from "./_generated/server"
import { auth } from "./auth"
import { privacy, terms } from "./legal"

/** The one page this system still needs to be a web page. */
const http = httpRouter()

// Token verification keys, and the return leg of Google, Facebook and Apple.
auth.addHttpRoutes(http)

http.route({
  path: "/pay/done",
  method: "GET",
  handler: httpAction(async () => {
    return new Response(
      `<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Personal OS</title>
<style>
  :root { color-scheme: light dark }
  body { margin: 0; display: grid; place-items: center; min-height: 100vh;
         font: 17px/1.5 -apple-system, system-ui, sans-serif; text-align: center }
  main { padding: 28px; max-width: 30rem }
  h1 { font-weight: 600; font-size: 1.3rem; margin: 0 0 .5rem }
  p { margin: 0; opacity: .7 }
</style>
<main>
  <h1>Thank you</h1>
  <p>You can close this page and return to Personal OS. It checks the payment with the processor itself.</p>
</main>`,
      { status: 200, headers: { "content-type": "text/html; charset=utf-8" } },
    )
  }),
})

http.route({
  path: "/payouts/done",
  method: "GET",
  handler: httpAction(async () => {
    return new Response(
      `<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Personal OS</title>
<style>
  :root { color-scheme: light dark }
  body { margin: 0; display: grid; place-items: center; min-height: 100vh;
         font: 17px/1.5 -apple-system, system-ui, sans-serif; text-align: center }
  main { padding: 28px; max-width: 30rem }
  h1 { font-weight: 600; font-size: 1.3rem; margin: 0 0 .5rem }
  p { margin: 0; opacity: .7 }
</style>
<main>
  <h1>Thank you</h1>
  <p>You can close this page and return to Personal OS. It will ask Stripe whether your account is ready; that can take a little while after you finish.</p>
</main>`,
      { status: 200, headers: { "content-type": "text/html; charset=utf-8" } },
    )
  }),
})

// Asked for by Google's consent screen, Meta's app review and the App Store, and by anyone who
// wants to know what the app does with their health data.
http.route({ path: "/privacy", method: "GET", handler: httpAction(async () => privacy()) })
http.route({ path: "/terms", method: "GET", handler: httpAction(async () => terms()) })

export default http
