# Migrating to Convex

## Why Convex is Perfect for This

✅ Serverless database (no SQLite filesystem issues)
✅ Works perfectly with Vercel
✅ Real-time updates out of the box
✅ TypeScript-first
✅ Generous free tier (1M reads/month, 100K writes/month)
✅ Built-in file storage (for future features)

## What We Need to Migrate

### Current SQLite Databases:
1. **Business** (`Business/data/crm.db`)
   - `contacts` table
   - `interactions` table

2. **Marketing** (`Market/data/marketing.db`)
   - `posts` table

3. **Well Being** (`Well Being/data/health.db`)
   - `health_records` table
   - `activity_tracking` table
   - `ai_reports` table

4. **Data Science** (`Data Science/data_science/tracker.csv`)
   - Can move to Convex too

### What About Ollama?

We still need to handle Ollama for AI features. Two options:
1. **Keep hybrid:** Ollama on a separate server (your Mac with ngrok, or Railway)
2. **Switch to OpenAI/Anthropic:** Use cloud AI APIs (costs ~$1-5/month)

## Migration Steps

### Step 1: Install Convex (2 minutes)

```bash
cd /Users/akio/personal_os/web
npm install convex
npx convex dev
```

This will:
- Create a Convex project
- Generate `convex/` folder
- Set up authentication

### Step 2: Define Schemas (10 minutes)

Create Convex tables to match your SQLite structure:

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Business
  contacts: defineTable({
    name: v.string(),
    email: v.optional(v.string()),
    phone: v.optional(v.string()),
    company: v.optional(v.string()),
    status: v.string(), // 'lead', 'prospect', 'client'
    notes: v.optional(v.string()),
    created_at: v.number(),
  }).index("by_status", ["status"]),

  interactions: defineTable({
    contact_id: v.id("contacts"),
    type: v.string(),
    date: v.number(),
    notes: v.string(),
  }).index("by_contact", ["contact_id"]),

  // Marketing
  posts: defineTable({
    content: v.string(),
    platform: v.string(),
    topic: v.optional(v.string()),
    mood: v.optional(v.string()),
    bullets: v.optional(v.string()),
    published: v.boolean(),
    created_at: v.number(),
  }).index("by_published", ["published"]),

  // Well Being
  health_records: defineTable({
    date: v.number(),
    steps: v.optional(v.number()),
    distance: v.optional(v.number()),
    flights_climbed: v.optional(v.number()),
    walking_speed: v.optional(v.number()),
    walking_steadiness: v.optional(v.number()),
    source: v.optional(v.string()),
  }).index("by_date", ["date"]),

  activity_tracking: defineTable({
    date: v.number(),
    screen_time: v.number(),
    top_app: v.string(),
    top_app_time: v.number(),
    second_app: v.optional(v.string()),
    second_app_time: v.optional(v.number()),
    third_app: v.optional(v.string()),
    third_app_time: v.optional(v.number()),
  }).index("by_date", ["date"]),

  ai_reports: defineTable({
    type: v.string(), // 'daily', 'weekly', 'monthly'
    content: v.string(),
    created_at: v.number(),
  }).index("by_type", ["type"]),

  // Data Science
  projects: defineTable({
    name: v.string(),
    description: v.optional(v.string()),
    status: v.string(), // 'In Progress', 'Completed', 'Paused'
    started_date: v.optional(v.string()),
    completed_date: v.optional(v.string()),
    deployed_url: v.optional(v.string()),
    github_url: v.optional(v.string()),
    tags: v.optional(v.string()),
  }).index("by_status", ["status"]),
});
```

### Step 3: Create Convex Functions (20 minutes)

Replace your Next.js API routes with Convex queries and mutations:

```typescript
// convex/business.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get all contacts
export const getContacts = query({
  handler: async (ctx) => {
    return await ctx.db.query("contacts").order("desc").collect();
  },
});

// Add a contact
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
    return await ctx.db.insert("contacts", {
      ...args,
      created_at: Date.now(),
    });
  },
});

// Get pipeline summary
export const getPipelineSummary = query({
  handler: async (ctx) => {
    const contacts = await ctx.db.query("contacts").collect();
    
    const summary = contacts.reduce((acc, contact) => {
      acc[contact.status] = (acc[contact.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    return { summary };
  },
});
```

### Step 4: Update Frontend (30 minutes)

Replace fetch calls with Convex hooks:

```typescript
// Before (API route):
const res = await fetch('/api/business/contacts');
const data = await res.json();

// After (Convex):
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";

const contacts = useQuery(api.business.getContacts);
```

### Step 5: Migrate Data (15 minutes)

I'll create a migration script to export SQLite → import to Convex:

```typescript
// scripts/migrate-to-convex.ts
import Database from 'better-sqlite3';
import { ConvexHttpClient } from "convex/browser";

async function migrate() {
  const client = new ConvexHttpClient(process.env.CONVEX_URL!);
  
  // Migrate contacts
  const crmDb = new Database('./Business/data/crm.db');
  const contacts = crmDb.prepare('SELECT * FROM contacts').all();
  
  for (const contact of contacts) {
    await client.mutation(api.business.addContact, contact);
  }
  
  // ... repeat for other tables
}
```

### Step 6: Handle Ollama

Two options:

**Option A: Keep Ollama Separate (Simple)**
- Deploy a tiny Express server on Railway ($5/month)
- Just handles AI requests
- Frontend + Convex on Vercel, AI on Railway

**Option B: Switch to OpenAI (Easier)**
- Replace Ollama calls with OpenAI API
- Everything on Vercel + Convex
- ~$1-5/month depending on usage

## Cost Comparison

| Service | SQLite + Ollama (Local) | Convex + Railway | Convex + OpenAI |
|---------|------------------------|------------------|-----------------|
| Database | Free | Free | Free |
| AI | Free | $5/month | $1-5/month |
| Backend | Local only | Global | Global |
| Hosting | Not possible | Vercel (free) | Vercel (free) |
| **Total** | $0 (local) | $5/month | $1-5/month |

## Timeline

- **Just Convex migration:** 1-2 hours
- **Full deployment with Ollama on Railway:** 2-3 hours
- **Full deployment with OpenAI:** 1-2 hours (simpler)

## My Recommendation

1. **Migrate to Convex** (better than SQLite for this use case)
2. **Keep Ollama on Railway** ($5/month) - you keep free AI + full control
3. **Deploy frontend to Vercel** (free)

Total: $5/month for a globally available app

Want me to start the migration? I can:
1. Set up Convex schema
2. Create all the queries/mutations
3. Update your frontend components
4. Create the data migration script
5. Set up Railway for Ollama (or switch to OpenAI if you prefer)
