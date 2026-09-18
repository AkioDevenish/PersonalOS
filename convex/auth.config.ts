/**
 * Which tokens Convex believes.
 *
 * Only ones this deployment signed itself, through Convex Auth. This used to
 * name Clerk's issuer; a token from there is now refused.
 *
 * Getting this wrong fails silently — every request simply arrives signed out
 * with no error to say why — which is why it is its own file with one entry.
 */
export default {
  providers: [
    {
      domain: process.env.CONVEX_SITE_URL,
      applicationID: "convex",
    },
  ],
}
