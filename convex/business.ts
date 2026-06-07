import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Contacts
export const getContacts = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .order("desc")
      .collect();
  },
});

export const addContact = mutation({
  args: {
    name: v.string(),
    email: v.optional(v.string()),
    phone: v.optional(v.string()),
    company: v.optional(v.string()),
    status: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db.insert("contacts", {
      ...args,
      userId: identity.subject,
      created_at: Date.now(),
    });
  },
});

export const updateContact = mutation({
  args: {
    id: v.id("contacts"),
    name: v.optional(v.string()),
    email: v.optional(v.string()),
    phone: v.optional(v.string()),
    company: v.optional(v.string()),
    status: v.optional(v.string()),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const { id, ...updates } = args;
    
    // Verify ownership
    const contact = await ctx.db.get(id);
    if (!contact || contact.userId !== identity.subject) {
      throw new Error("Contact not found or unauthorized");
    }
    
    await ctx.db.patch(id, updates);
  },
});

// Interactions
export const getInteractions = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const interactions = await ctx.db
      .query("interactions")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .order("desc")
      .take(100);
    
    // Join with contacts to get contact names
    const withContacts = await Promise.all(
      interactions.map(async (interaction) => {
        const contact = await ctx.db.get(interaction.contact_id);
        return {
          ...interaction,
          contact_name: contact?.name || "Unknown",
        };
      })
    );
    
    return withContacts;
  },
});

export const addInteraction = mutation({
  args: {
    contact_id: v.id("contacts"),
    type: v.string(),
    date: v.number(),
    notes: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    // Verify contact ownership
    const contact = await ctx.db.get(args.contact_id);
    if (!contact || contact.userId !== identity.subject) {
      throw new Error("Contact not found or unauthorized");
    }
    
    return await ctx.db.insert("interactions", {
      ...args,
      userId: identity.subject,
    });
  },
});

// Pipeline Summary
export const getPipelineSummary = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    const contacts = await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect();
    
    const summary = contacts.reduce((acc, contact) => {
      acc[contact.status] = (acc[contact.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    return { summary };
  },
});
