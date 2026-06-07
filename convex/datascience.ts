import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getProjects = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db
      .query("projects")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect();
  },
});

export const addProject = mutation({
  args: {
    name: v.string(),
    description: v.optional(v.string()),
    status: v.string(),
    started_date: v.optional(v.string()),
    completed_date: v.optional(v.string()),
    deployed_url: v.optional(v.string()),
    github_url: v.optional(v.string()),
    tags: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("projects", {
      ...args,
      userId: identity.subject,
    });
  },
});

export const updateProject = mutation({
  args: {
    id: v.id("projects"),
    name: v.optional(v.string()),
    description: v.optional(v.string()),
    status: v.optional(v.string()),
    started_date: v.optional(v.string()),
    completed_date: v.optional(v.string()),
    deployed_url: v.optional(v.string()),
    github_url: v.optional(v.string()),
    tags: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const { id, ...updates } = args;
    
    // Verify ownership
    const project = await ctx.db.get(id);
    if (!project || project.userId !== identity.subject) {
      throw new Error("Project not found or unauthorized");
    }
    
    await ctx.db.patch(id, updates);
  },
});

export const getTracker = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const projects = await ctx.db
      .query("projects")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect();
    
    return { projects };
  },
});
