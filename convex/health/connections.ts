import { v } from "convex/values"
import { mutation, query, internalQuery, internalMutation } from "../_generated/server"
import { isProvider, isMetricKey, defaultPriority, type MetricKey } from "./metrics"
import { CONNECTABLE, PROVIDER_INFO, providerInfo } from "./providers"

/**
 * Provider connection lifecycle, plus the per-user trust-order override.
 *
 * No OAuth tokens here — see the note on health_connections in schema.ts.
 */

export const list = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    return await ctx.db
      .query("health_connections")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect()
  },
})

/**
 * Every connectable provider merged with this user's connection state — one
 * uniform list for the settings screen, so Apple Health and Oura render as the
 * same kind of card even though their transports differ.
 */
export const available = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const rows = await ctx.db
      .query("health_connections")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect()

    const byProvider = new Map(rows.map((r) => [r.provider, r]))

    return CONNECTABLE.map((key) => {
      const info = PROVIDER_INFO[key]
      const conn = byProvider.get(key)
      return {
        key,
        label: info.label,
        kind: info.kind,
        platform: info.platform,
        highlights: info.highlights,
        status: conn?.status ?? "disconnected",
        last_sync_at: conn?.last_sync_at,
        last_error: conn?.last_error,
      }
    })
  },
})

/**
 * Begin (or repair) a connection.
 *
 * Cloud providers land here after the OAuth callback, with the provider's
 * account id — they are live immediately. Device providers land here when the
 * user taps Connect in the app, before any data exists, so they sit in
 * `pending` until the first batch actually arrives and ingest flips them to
 * `connected`. That distinction is what lets the UI honestly say "waiting for
 * your phone" instead of claiming a connection that has delivered nothing.
 */
export const connect = mutation({
  args: {
    provider: v.string(),
    external_user_id: v.optional(v.string()),
    scopes: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isProvider(args.provider)) throw new Error(`Unknown provider: ${args.provider}`)

    const info = providerInfo(args.provider)!
    const status = info.kind === "cloud" ? "connected" : "pending"

    const existing = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", identity.subject).eq("provider", args.provider),
      )
      .first()

    if (existing) {
      await ctx.db.patch(existing._id, {
        // a reconnect of a device provider that already has data stays connected
        status: existing.last_sync_at ? "connected" : status,
        external_user_id: args.external_user_id ?? existing.external_user_id,
        scopes: args.scopes ?? existing.scopes,
        last_error: undefined,
      })
      return existing._id
    }

    return await ctx.db.insert("health_connections", {
      userId: identity.subject,
      provider: args.provider,
      status,
      external_user_id: args.external_user_id,
      scopes: args.scopes,
      connected_at: Date.now(),
    })
  },
})

/**
 * Server-to-server link, used by the OAuth callback.
 *
 * The public `connect` derives the user from the session, but a callback has
 * no session it should trust — it has a signed state parameter naming the user
 * who began the flow. So identity is passed explicitly and this stays internal.
 */
export const linkForUser = internalMutation({
  args: {
    userId: v.string(),
    provider: v.string(),
    external_user_id: v.optional(v.string()),
    scopes: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    if (!isProvider(args.provider)) throw new Error(`Unknown provider: ${args.provider}`)

    const existing = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()

    if (existing) {
      await ctx.db.patch(existing._id, {
        status: "connected",
        external_user_id: args.external_user_id ?? existing.external_user_id,
        scopes: args.scopes ?? existing.scopes,
        last_error: undefined,
      })
      return existing._id
    }

    return await ctx.db.insert("health_connections", {
      userId: args.userId,
      provider: args.provider,
      status: "connected",
      external_user_id: args.external_user_id,
      scopes: args.scopes,
      connected_at: Date.now(),
    })
  },
})

/** Read the resume point so a sync knows where it left off. */
export const cursorFor = internalQuery({
  args: { userId: v.string(), provider: v.string() },
  handler: async (ctx, args) => {
    const conn = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()
    return conn?.sync_cursor ?? null
  },
})

export const setCursor = internalMutation({
  args: { userId: v.string(), provider: v.string(), cursor: v.string() },
  handler: async (ctx, args) => {
    const conn = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()
    if (conn) await ctx.db.patch(conn._id, { sync_cursor: args.cursor })
  },
})

/** Record a failed sync so the UI can show it rather than silently going stale. */
export const recordError = internalMutation({
  args: { userId: v.string(), provider: v.string(), error: v.string() },
  handler: async (ctx, args) => {
    const conn = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", args.userId).eq("provider", args.provider),
      )
      .first()
    if (conn) await ctx.db.patch(conn._id, { status: "error", last_error: args.error })
  },
})

/**
 * Disconnect a provider.
 *
 * `purge` deletes that provider's samples outright. Offer it — under GDPR and
 * the App Store health-data rules, "I revoked access" should be able to mean
 * "and delete what you took". Default is to keep history so a reconnect
 * doesn't lose a year of data, and because resolution will simply stop
 * choosing a provider once fresher sources exist.
 */
export const disconnect = mutation({
  args: { provider: v.string(), purge: v.optional(v.boolean()) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")

    const conn = await ctx.db
      .query("health_connections")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", identity.subject).eq("provider", args.provider),
      )
      .first()

    if (conn) await ctx.db.patch(conn._id, { status: "disconnected" })

    // Revoking access must not leave a usable refresh token behind — that is
    // the whole point of disconnecting.
    const token = await ctx.db
      .query("health_oauth_tokens")
      .withIndex("by_user_provider", (q) =>
        q.eq("userId", identity.subject).eq("provider", args.provider),
      )
      .first()
    if (token) await ctx.db.delete(token._id)

    let purged = 0
    if (args.purge) {
      // Bounded per call so a heavy account can't blow the transaction limit;
      // callers should re-invoke until purged === 0.
      const batch = await ctx.db
        .query("health_samples")
        .withIndex("by_user_provider", (q) =>
          q.eq("userId", identity.subject).eq("provider", args.provider),
        )
        .take(500)

      for (const doc of batch) {
        await ctx.db.delete(doc._id)
        purged++
      }
    }

    return { purged, done: purged < 500 }
  },
})

/** Map an aggregator's account id back to a Personal OS user, for webhooks. */
export const byExternalUser = internalQuery({
  args: { external_user_id: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("health_connections")
      .withIndex("by_external_user", (q) => q.eq("external_user_id", args.external_user_id))
      .first()
  },
})

/** Effective trust order for a metric — the user's override, else the default. */
export const priorityFor = query({
  args: { metric: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isMetricKey(args.metric)) throw new Error(`Unknown metric: ${args.metric}`)

    const override = await ctx.db
      .query("health_metric_sources")
      .withIndex("by_user_metric", (q) =>
        q.eq("userId", identity.subject).eq("metric", args.metric),
      )
      .first()

    return {
      metric: args.metric,
      priority: override?.priority ?? defaultPriority(args.metric as MetricKey),
      isDefault: !override,
    }
  },
})

export const setPriority = mutation({
  args: { metric: v.string(), priority: v.array(v.string()) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity()
    if (!identity) throw new Error("Not authenticated")
    if (!isMetricKey(args.metric)) throw new Error(`Unknown metric: ${args.metric}`)

    for (const p of args.priority) {
      if (!isProvider(p)) throw new Error(`Unknown provider: ${p}`)
    }

    const existing = await ctx.db
      .query("health_metric_sources")
      .withIndex("by_user_metric", (q) =>
        q.eq("userId", identity.subject).eq("metric", args.metric),
      )
      .first()

    if (existing) {
      await ctx.db.patch(existing._id, {
        priority: args.priority,
        updated_at: Date.now(),
      })
      return existing._id
    }

    return await ctx.db.insert("health_metric_sources", {
      userId: identity.subject,
      metric: args.metric,
      priority: args.priority,
      updated_at: Date.now(),
    })
  },
})
