import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { authTables } from "@convex-dev/auth/server";

export default defineSchema({
  /** Accounts, sessions and sign-in state, owned by this database. */
  ...authTables,

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

  // DEPRECATED: Apple-HealthKit-shaped, one column per metric, so every new provider would need a
  // migration.
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

  /** Provider-agnostic health samples (entity-attribute-value). */
  health_samples: defineTable({
    userId: v.string(), // Clerk user ID
    provider: v.string(), // see PROVIDERS in convex/health/metrics.ts
    metric: v.string(), // see METRICS
    value: v.number(),
    unit: v.string(), // canonical unit for the metric
    recorded_at: v.number(), // epoch ms, start of the sample
    period_end: v.optional(v.number()), // for interval samples (e.g. sleep)
    /** Calendar day (YYYY-MM-DD) in the user's timezone at ingest. */
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

  /** A user's link to one provider. */
  health_connections: defineTable({
    userId: v.string(),
    provider: v.string(),
    status: v.string(), // 'connected' | 'disconnected' | 'error' | 'pending'
    external_user_id: v.optional(v.string()), // provider/aggregator id
    scopes: v.optional(v.array(v.string())),
    last_sync_at: v.optional(v.number()),
    /** Opaque resume point for incremental sync. */
    sync_cursor: v.optional(v.string()),
    last_error: v.optional(v.string()),
    connected_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_provider", ["userId", "provider"])
    .index("by_external_user", ["external_user_id"]),

  /** Provider OAuth tokens, encrypted before they ever reach Convex. */
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
   * Per-user override of the default trust order — "use Oura for sleep even though I also wear a
   * Garmin".
   */
  health_metric_sources: defineTable({
    userId: v.string(),
    metric: v.string(),
    priority: v.array(v.string()), // provider keys, most trusted first
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_metric", ["userId", "metric"]),

  /** Bring-your-own-key credentials for AI platforms. */
  ai_keys: defineTable({
    userId: v.string(),
    provider: v.string(),
    api_key: v.string(), // encrypted envelope
    last4: v.string(),
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_provider", ["userId", "provider"]),

  /** What a user has paid for. */
  entitlements: defineTable({
    userId: v.string(),
    /** none | active | expired | grace | revoked */
    subscription_status: v.string(),
    product_id: v.optional(v.string()),
    expires_at: v.optional(v.number()),
    /** Apple's stable per-user id, for reconciling renewals. */
    original_transaction_id: v.optional(v.string()),
    updated_at: v.number(),
  }).index("by_user", ["userId"]),

  /** Every App Store purchase that has been applied. */
  purchase_receipts: defineTable({
    userId: v.string(),
    transactionId: v.string(),
    productId: v.string(),
    created_at: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_transactionId", ["transactionId"]),

  /** Which platform and model this user's insights should run on. */
  /** A conversation with a nutritionist. */
  /** A nutritionist people can choose to ask. */
  nutritionists: defineTable({
    userId: v.string(),
    name: v.string(),
    country: v.string(),          // ISO region code
    credentials: v.string(),      // "RD, MSc Nutrition" — as they state it
    bio: v.string(),
    /** What this person will actually answer about: "Diabetes", "Sports nutrition", "Sleep". */
    specialties: v.optional(v.array(v.string())),
    /** Whether this person will take a video call as well as a written one. */
    offers_video: v.optional(v.boolean()),
    /** Their photograph, in Convex file storage. */
    photo: v.optional(v.id("_storage")),
    /** When this practitioner's app last said it was awake. */
    last_seen: v.optional(v.number()),
    /** Where the application stands: "pending", "approved", "declined". */
    status: v.optional(v.string()),
    /** What one consultation costs, in credits. */
    price_credits: v.number(),
    /** What a consultation costs, in integer minor units of `currency`. */
    price_minor: v.optional(v.number()),
    currency: v.optional(v.string()),      // ISO 4217
    /** The practitioner's own Stripe account, created through Connect. */
    stripe_account: v.optional(v.string()),
    /** Whether Stripe says that account can actually be paid yet. */
    payouts_enabled: v.optional(v.boolean()),
    active: v.boolean(),
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_active", ["active"])
    .index("by_status", ["status"]),

  consults: defineTable({
    userId: v.string(),
    /** Which professional was asked, when one was chosen. */
    nutritionistId: v.optional(v.string()),
    topic: v.string(),
    status: v.string(),          // waiting | answered | closed
    /** The readings shared at the moment of asking, as shown to the user. */
    shared: v.optional(v.string()),
    /** "text" or "video". */
    kind: v.optional(v.string()),
    /** The call's room, when there is one. */
    room: v.optional(v.string()),
    /** What was actually taken for this session, so the ledger can be audited. */
    paid_credits: v.optional(v.number()),
    /**
     * The agreed price, captured at the moment of opening so a later change to the practitioner's
     * rate cannot rewrite what somebody already owed.
     */
    price_minor: v.optional(v.number()),
    currency: v.optional(v.string()),
    /** "free", "pending" or "paid". */
    payment_status: v.optional(v.string()),
    /** The processor's own reference, once there is a processor. */
    payment_ref: v.optional(v.string()),
    /** The platform's share of this consultation, in minor units. */
    platform_fee_minor: v.optional(v.number()),
    /** True when the fee was collected without a split, so the practitioner is owed their share. */
    payout_owed: v.optional(v.boolean()),
    country: v.optional(v.string()),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_status", ["status"]),

  /** How two phones find each other for a call. */
  /** Articles written by practitioners, and where each one stands. */
  articles: defineTable({
    authorToken: v.string(),
    authorId: v.string(),
    title: v.string(),
    category: v.string(),
    summary: v.string(),
    body: v.string(),
    symbol: v.string(),
    colour: v.string(),
    minutes: v.number(),
    /**
     * approved is verified by the team and waiting for the author to pay; published is paid and on
     * Home until live_until; expired is a published article whose paid time ran out, ready to
     * renew.
     */
    status: v.union(
      v.literal("draft"),
      v.literal("submitted"),
      v.literal("changes_requested"),
      v.literal("approved"),
      v.literal("published"),
      v.literal("expired"),
      v.literal("withdrawn"),
    ),
    /** Soft findings from the automatic check, for the reviewer to weigh. */
    flags: v.array(v.string()),
    review_note: v.optional(v.string()),
    reviewed_by: v.optional(v.string()),
    submitted_at: v.optional(v.number()),
    published_at: v.optional(v.number()),
    /** When the paid time on Home ends. */
    live_until: v.optional(v.number()),
    /**
     * The UUID StoreKit carries through a purchase as appAccountToken, which is how a signed
     * transaction is tied to this article and no other.
     */
    payment_token: v.optional(v.string()),
    updated_at: v.number(),
  })
    .index("by_authorToken_and_updated_at", ["authorToken", "updated_at"])
    .index("by_payment_token", ["payment_token"])
    .index("by_status_and_submitted_at", ["status", "submitted_at"])
    .index("by_status_and_published_at", ["status", "published_at"]),

  /** Every App Store transaction that paid for time on Home. */
  article_payments: defineTable({
    articleId: v.id("articles"),
    authorToken: v.string(),
    transactionId: v.string(),
    productId: v.string(),
    live_until: v.number(),
    created_at: v.number(),
  }).index("by_transactionId", ["transactionId"]),

  /** Devices to push to, one row per install. */
  push_devices: defineTable({
    userId: v.string(),
    token: v.string(),
    platform: v.string(),
    updated_at: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_token", ["token"]),

  call_signals: defineTable({
    consultId: v.id("consults"),
    /** Who sent it, so a phone never answers its own message. */
    from: v.string(),
    /** "offer", "answer", "candidate", or "bye". */
    kind: v.string(),
    /** The SDP or ICE candidate, as the browser stack produced it. */
    payload: v.string(),
    created_at: v.number(),
  })
    .index("by_consult", ["consultId"])
    .index("by_consult_time", ["consultId", "created_at"]),

  consult_messages: defineTable({
    consultId: v.id("consults"),
    /** "you" or "nutritionist" — who the message reads as, not who wrote it. */
    from: v.string(),
    authorId: v.string(),
    body: v.string(),
    created_at: v.number(),
  }).index("by_consult", ["consultId"]),

  /** What people in a country actually eat, and who said so. */
  cuisine_dishes: defineTable({
    country: v.string(),        // ISO region code, e.g. "TT"
    dish: v.string(),           // as typed, for display
    key: v.string(),            // normalised, for counting
    userId: v.string(),         // one vote each
    reject: v.optional(v.boolean()), // "not eaten here" rather than a vote
    created_at: v.number(),
  })
    .index("by_country", ["country"])
    .index("by_country_key", ["country", "key"])
    .index("by_country_user", ["country", "userId"]),

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

  // Finance

  /** One movement of money. */
  finance_entries: defineTable({
    userId: v.string(), // Clerk user ID
    date: v.number(), // when the money moved, not when it was recorded
    minor: v.number(), // signed integer minor units
    currency: v.string(), // ISO 4217
    category: v.string(),
    note: v.optional(v.string()),
    source: v.string(), // "manual", or the feed that imported it
    external_id: v.optional(v.string()), // the provider's id, for deduplication
    created_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_date", ["userId", "date"])
    .index("by_user_source_external", ["userId", "source", "external_id"]),

  // Time

  /** A stretch of time that went somewhere. */
  time_blocks: defineTable({
    userId: v.string(), // Clerk user ID
    start: v.number(),
    minutes: v.number(),
    activity: v.string(),
    category: v.string(),
    note: v.optional(v.string()),
    source: v.string(),
    external_id: v.optional(v.string()),
    created_at: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_start", ["userId", "start"])
    .index("by_user_source_external", ["userId", "source", "external_id"]),
});
