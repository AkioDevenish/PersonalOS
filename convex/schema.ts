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
