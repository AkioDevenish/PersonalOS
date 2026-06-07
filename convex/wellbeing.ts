import { query, mutation, internalMutation } from "./_generated/server";
import { v } from "convex/values";

// Health Records
export const getHealthRecords = query({
  args: {
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const days = args.days || 7;
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
    
    const records = await ctx.db
      .query("health_records")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .filter((q) => q.gte(q.field("timestamp"), cutoff))
      .order("desc")
      .collect();
    
    return { records };
  },
});

export const addHealthRecord = mutation({
  args: {
    timestamp: v.number(),
    steps: v.optional(v.number()),
    distance: v.optional(v.number()),
    flights_climbed: v.optional(v.number()),
    walking_speed: v.optional(v.number()),
    walking_steadiness: v.optional(v.number()),
    source: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("health_records", {
      ...args,
      userId: identity.subject,
    });
  },
});

// AI Reports
export const getAiReports = query({
  args: {
    type: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const limit = args.limit || 10;
    
    let reports;
    
    if (args.type) {
      const reportType = args.type; // Extract to const for type narrowing
      reports = await ctx.db
        .query("ai_reports")
        .withIndex("by_user_type", (q) => 
          q.eq("userId", identity.subject).eq("type", reportType)
        )
        .order("desc")
        .take(limit);
    } else {
      reports = await ctx.db
        .query("ai_reports")
        .withIndex("by_user", (q) => q.eq("userId", identity.subject))
        .order("desc")
        .take(limit);
    }
    
    return { reports };
  },
});

export const addAiReport = mutation({
  args: {
    type: v.string(),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("ai_reports", {
      ...args,
      userId: identity.subject,
      created_at: Date.now(),
    });
  },
});

// Activity Tracking
export const getActivityTracking = query({
  args: {
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const days = args.days || 7;
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
    
    const activities = await ctx.db
      .query("activity_tracking")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .filter((q) => q.gte(q.field("timestamp"), cutoff))
      .order("desc")
      .collect();
    
    return { activities };
  },
});

export const addActivityTracking = mutation({
  args: {
    date: v.string(),
    screen_time: v.number(),
    top_app: v.string(),
    top_app_time: v.number(),
    second_app: v.optional(v.string()),
    second_app_time: v.optional(v.number()),
    third_app: v.optional(v.string()),
    third_app_time: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("activity_tracking", {
      ...args,
      userId: identity.subject,
      timestamp: Date.now(),
    });
  },
});

// Sync endpoint (for bulk inserts)
export const syncHealthData = mutation({
  args: {
    records: v.array(
      v.object({
        timestamp: v.number(),
        steps: v.optional(v.number()),
        distance: v.optional(v.number()),
        flights_climbed: v.optional(v.number()),
        walking_speed: v.optional(v.number()),
        walking_steadiness: v.optional(v.number()),
        source: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const results = await Promise.all(
      args.records.map((record) => ctx.db.insert("health_records", {
        ...record,
        userId: identity.subject,
      }))
    );
    return { count: results.length };
  },
});

export const syncHealthDataInternal = internalMutation({
  args: {
    userId: v.string(),
    records: v.array(
      v.object({
        timestamp: v.number(),
        steps: v.optional(v.number()),
        distance: v.optional(v.number()),
        flights_climbed: v.optional(v.number()),
        walking_speed: v.optional(v.number()),
        walking_steadiness: v.optional(v.number()),
        source: v.optional(v.string()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const results = await Promise.all(
      args.records.map((record) => ctx.db.insert("health_records", {
        ...record,
        userId: args.userId,
      }))
    );
    return { count: results.length };
  },
});
