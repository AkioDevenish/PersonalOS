import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getPosts = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const limit = args.limit || 20;
    return await ctx.db
      .query("posts")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .order("desc")
      .take(limit);
  },
});

export const addPost = mutation({
  args: {
    content: v.string(),
    platform: v.string(),
    topic: v.optional(v.string()),
    mood: v.optional(v.string()),
    bullets: v.optional(v.string()),
    published: v.boolean(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("posts", {
      ...args,
      userId: identity.subject,
      created_at: Date.now(),
    });
  },
});

export const updatePost = mutation({
  args: {
    id: v.id("posts"),
    content: v.optional(v.string()),
    published: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const { id, ...updates } = args;
    
    // Verify ownership
    const post = await ctx.db.get(id);
    if (!post || post.userId !== identity.subject) {
      throw new Error("Post not found or unauthorized");
    }
    
    await ctx.db.patch(id, updates);
  },
});

export const getStats = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const posts = await ctx.db
      .query("posts")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect();
    
    const totalPosts = posts.length;
    const publishedPosts = posts.filter((p) => p.published).length;
    
    // Posts this week
    const oneWeekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const postsThisWeek = posts.filter((p) => p.created_at >= oneWeekAgo).length;
    
    // By platform
    const byPlatform = posts.reduce((acc, post) => {
      acc[post.platform] = (acc[post.platform] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    return {
      total: totalPosts,
      published: publishedPosts,
      this_week: postsThisWeek,
      by_platform: byPlatform,
    };
  },
});
