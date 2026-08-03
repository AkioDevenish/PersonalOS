import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Business - CRM
  contacts: defineTable({
    userId: v.string(), // Clerk user ID
    name: v.string(),
    email: v.optional(v.string()),
    phone: v.optional(v.string()),
    company: v.optional(v.string()),
    status: v.string(), // 'lead', 'prospect', 'client', 'proposal'
    notes: v.optional(v.string()),
    created_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_status", ["userId", "status"])
    .index("by_created", ["created_at"]),

  interactions: defineTable({
    userId: v.string(), // Clerk user ID
    contact_id: v.id("contacts"),
    type: v.string(),
    date: v.number(),
    notes: v.string(),
  })
    .index("by_user", ["userId"])
    .index("by_contact", ["contact_id"])
    .index("by_date", ["date"]),

  // Marketing
  posts: defineTable({
    userId: v.string(), // Clerk user ID
    content: v.string(),
    platform: v.string(),
    topic: v.optional(v.string()),
    mood: v.optional(v.string()),
    bullets: v.optional(v.string()),
    published: v.boolean(),
    created_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_published", ["published"])
    .index("by_created", ["created_at"])
    .index("by_platform", ["platform"]),

  // Well Being

  // DEPRECATED: Apple-HealthKit-shaped, one column per metric, so every new
  // provider would need a migration. Superseded by health_samples below.
  // Kept until the existing read paths are moved over.
  health_records: defineTable({
    userId: v.string(), // Clerk user ID
    timestamp: v.number(),
    steps: v.optional(v.number()),
    distance: v.optional(v.number()),
    flights_climbed: v.optional(v.number()),
    walking_speed: v.optional(v.number()),
    walking_steadiness: v.optional(v.number()),
    source: v.optional(v.string()),
  })
    .index("by_user", ["userId"])
    .index("by_timestamp", ["timestamp"])
    .index("by_user_timestamp", ["userId", "timestamp"])
    .index("by_source", ["source"]),

  /**
   * Provider-agnostic health samples (entity-attribute-value).
   *
   * Adding a provider or a metric is data, never a schema change. Raw rows
   * from every connected provider are kept side by side — overlap is resolved
   * at read time by convex/health/resolve.ts, never by discarding on write, so
   * changing the trust order re-resolves history instead of losing it.
   */
  health_samples: defineTable({
    userId: v.string(), // Clerk user ID
    provider: v.string(), // see PROVIDERS in convex/health/metrics.ts
    metric: v.string(), // see METRICS
    value: v.number(),
    unit: v.string(), // canonical unit for the metric
    recorded_at: v.number(), // epoch ms, start of the sample
    period_end: v.optional(v.number()), // for interval samples (e.g. sleep)
    /**
     * Calendar day (YYYY-MM-DD) in the user's timezone at ingest. Denormalised
     * because bucketing by day in a query would otherwise mean reading a whole
     * range and grouping in JS on every request.
     */
    day: v.string(),
    /** Provider's own id for the sample, when it has one — used for idempotency. */
    external_id: v.optional(v.string()),
    device: v.optional(v.string()), // e.g. "Apple Watch Series 9"
    ingested_at: v.number(),
  })
    // resolution: every sample for one user/day/metric across all providers
    .index("by_user_day_metric", ["userId", "day", "metric"])
    // time series for a single metric
    .index("by_user_metric_recorded", ["userId", "metric", "recorded_at"])
    // idempotent upsert + per-provider purge on disconnect
    .index("by_user_provider_metric_recorded", [
      "userId",
      "provider",
      "metric",
      "recorded_at",
    ])
    .index("by_user_provider", ["userId", "provider"]),

  /**
   * A user's link to one provider. OAuth tokens are deliberately NOT stored
   * here: they live with the aggregator, or in a secrets store. Convex
   * documents are readable by any function, so a leaked query is a leaked
   * token — keep this table to non-secret connection state.
   */
  health_connections: defineTable({
    userId: v.string(),
    provider: v.string(),
    status: v.string(), // 'connected' | 'disconnected' | 'error' | 'pending'
    external_user_id: v.optional(v.string()), // provider/aggregator id
    scopes: v.optional(v.array(v.string())),
    last_sync_at: v.optional(v.number()),
    /**
     * Opaque resume point for incremental sync. A timestamp is not enough:
     * HealthKit hands back a serialised HKQueryAnchor and several cloud
     * providers hand back a cursor rather than a date. Storing the provider's
     * own token means we fetch true deltas — and, for HealthKit, learn about
     * deletions, which a date-range query never reports.
     */
    sync_cursor: v.optional(v.string()),
    last_error: v.optional(v.string()),
    connected_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_provider", ["userId", "provider"])
    .index("by_external_user", ["external_user_id"]),

  /**
   * Provider OAuth tokens, encrypted before they ever reach Convex.
   *
   * The decryption key lives in the Next.js environment only, so these
   * documents are unreadable from inside Convex — a query that accidentally
   * returned every row would leak ciphertext and nothing else. Separate from
   * health_connections so ordinary connection reads never touch them.
   */
  health_oauth_tokens: defineTable({
    userId: v.string(),
    provider: v.string(),
    access_token: v.string(), // encrypted envelope
    refresh_token: v.optional(v.string()), // encrypted envelope
    expires_at: v.optional(v.number()),
    scopes: v.optional(v.array(v.string())),
    updated_at: v.number(),
  }).index("by_user_provider", ["userId", "provider"]),

  /**
   * Per-user override of the default trust order — "use Oura for sleep even
   * though I also wear a Garmin". Absent means the default in metrics.ts.
   */
  health_metric_sources: defineTable({
    userId: v.string(),
    metric: v.string(),
    priority: v.array(v.string()), // provider keys, most trusted first
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_metric", ["userId", "metric"]),

  /**
   * Bring-your-own-key credentials for AI platforms.
   *
   * Same posture as health_oauth_tokens and for the same reason: an API key is
   * a billable secret, so Convex only ever holds the ciphertext. `last4` is
   * stored separately in the clear so the app can show which key is saved
   * without anything having to decrypt it just to render a list.
   */
  ai_keys: defineTable({
    userId: v.string(),
    provider: v.string(),
    api_key: v.string(), // encrypted envelope
    last4: v.string(),
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_provider", ["userId", "provider"]),

  /**
   * Which platform and model this user's insights should run on. One row per
   * user; absent means fall back to whatever the server has configured.
   */
  ai_preferences: defineTable({
    userId: v.string(),
    provider: v.string(),
    model: v.string(),
    updated_at: v.number(),
  }).index("by_user", ["userId"]),

  activity_tracking: defineTable({
    userId: v.string(), // Clerk user ID
    date: v.string(), // YYYY-MM-DD format
    screen_time: v.number(),
    top_app: v.string(),
    top_app_time: v.number(),
    second_app: v.optional(v.string()),
    second_app_time: v.optional(v.number()),
    third_app: v.optional(v.string()),
    third_app_time: v.optional(v.number()),
    timestamp: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_date", ["date"])
    .index("by_user_date", ["userId", "date"]),

  ai_reports: defineTable({
    userId: v.string(), // Clerk user ID
    type: v.string(), // 'daily', 'weekly', 'monthly'
    content: v.string(),
    created_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_type", ["type"])
    .index("by_user_type", ["userId", "type"])
    .index("by_created", ["created_at"]),

  // Data Science
  projects: defineTable({
    userId: v.string(), // Clerk user ID
    name: v.string(),
    description: v.optional(v.string()),
    status: v.string(), // 'In Progress', 'Completed', 'Paused'
    started_date: v.optional(v.string()),
    completed_date: v.optional(v.string()),
    deployed_url: v.optional(v.string()),
    github_url: v.optional(v.string()),
    tags: v.optional(v.string()),
  })
    .index("by_user", ["userId"])
    .index("by_status", ["status"])
    .index("by_user_status", ["userId", "status"])
    .index("by_name", ["name"]),
});
