# 🔐 Authentication Setup with Clerk

## Overview

Personal OS now uses **Clerk** for authentication, enabling:
- ✅ Multi-user accounts (each user has their own data)
- ✅ Social login (Google, GitHub, etc.)
- ✅ Email/password authentication
- ✅ Secure session management
- ✅ User profiles with avatars
- ✅ Magic link signin
- ✅ Two-factor authentication (optional)

---

## 🎉 Implementation Status: COMPLETE

### ✅ Completed Tasks

#### Authentication Infrastructure
- ✅ Installed and configured @clerk/nextjs
- ✅ Created middleware.ts with route protection
- ✅ Wrapped app in ClerkProvider with branded appearance
- ✅ Created branded sign-in page at `/sign-in/[[...sign-in]]/page.tsx`
- ✅ Created branded sign-up page at `/sign-up/[[...sign-up]]/page.tsx`
- ✅ Updated Header component to use UserButton
- ✅ Updated landing page to redirect authenticated users
- ✅ Updated ConvexClientProvider to use ConvexProviderWithClerk
- ✅ Created hub/layout.tsx with server-side auth check

#### Database & Security
- ✅ Updated Convex schema with userId fields for ALL tables
- ✅ Added user-scoped indexes (by_user, by_user_status, by_user_type, etc.)
- ✅ **Updated ALL Convex functions with authentication:**
  - ✅ business.ts (contacts, interactions, pipeline)
  - ✅ marketing.ts (posts, stats)
  - ✅ wellbeing.ts (health records, activity tracking, AI reports, sync)
  - ✅ datascience.ts (projects, tracker)
- ✅ Added ownership verification for all mutations
- ✅ All queries filter by userId
- ✅ All mutations inject userId on creation

#### User Experience
- ✅ Landing page (/) is public
- ✅ Sign-in/sign-up pages are public and branded
- ✅ All /hub routes require authentication
- ✅ Unauthenticated users redirected to sign-in
- ✅ After sign-in → redirected to /hub
- ✅ User avatar in header with account management
- ✅ Complete data isolation per user

---

## Quick Start

### 1. Create a Clerk Account

1. Go to https://clerk.com
2. Sign up for a free account
3. Create a new application
4. Choose authentication methods you want to enable

### 2. Get API Keys

From your Clerk Dashboard:

1. Go to **API Keys** in the sidebar
2. Copy your keys:
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
   - `CLERK_SECRET_KEY`

### 3. Add Environment Variables

Create `.env.local` with:

```bash
# Clerk Authentication
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxx
CLERK_SECRET_KEY=sk_test_xxxxxxxxxxxxx

# Clerk URLs (these are the defaults)
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/hub
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/hub

# Convex
NEXT_PUBLIC_CONVEX_URL=https://astute-ant-253.convex.cloud

# Ollama (via ngrok)
NEXT_PUBLIC_OLLAMA_URL=https://your-ngrok-url.ngrok.app
```

### 4. Configure Convex for Clerk

Run this command to set up Convex authentication:

```bash
cd /Users/akio/personal_os/web
npx convex dev --configure=clerk
```

This will:
- Add Clerk as an auth provider in Convex
- Generate the necessary configuration
- Enable authenticated queries/mutations

### 5. Deploy Updated Schema

The schema has been updated to include `userId` fields. Deploy it:

```bash
CONVEX_DEPLOYMENT=prod:astute-ant-253 npx convex deploy
```

### 6. Test Locally

```bash
npm run dev
```

Visit `http://localhost:3000`:
- Landing page is public
- Click "Sign Up" to create an account
- After sign up, you're redirected to `/hub`
- All data is now scoped to your user account

---

## Authentication Implementation Details

### Schema Updates

All tables include `userId`:

```typescript
contacts: defineTable({
  userId: v.string(), // Clerk user ID
  name: v.string(),
  // ... other fields
})
.index("by_user", ["userId"])
```

### Query Pattern (All Files Updated)

```typescript
export const getContacts = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Not authenticated");
    }
    
    return await ctx.db
      .query("contacts")
      .withIndex("by_user", (q) => q.eq("userId", identity.subject))
      .collect();
  },
});
```

### Mutation Pattern (All Files Updated)

```typescript
export const addContact = mutation({
  args: { name: v.string(), /* ... */ },
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
```

### Update Pattern with Ownership Verification

```typescript
export const updateContact = mutation({
  args: { id: v.id("contacts"), /* ... */ },
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
```

### Protected Routes

Middleware protects all routes except:
- `/` (landing page)
- `/sign-in`
- `/sign-up`
- `/api/webhooks`

```typescript
// middleware.ts
const isPublicRoute = createRouteMatcher([
  '/',
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/webhooks(.*)',
])

export default clerkMiddleware(async (auth, request) => {
  if (!isPublicRoute(request)) {
    await auth.protect()
  }
})
```

---

## User Experience

### Sign Up Flow

1. User visits `/sign-up`
2. Sees branded sign-up form with pocket watch logo
3. Can sign up with:
   - Email + password
   - Google (if enabled)
   - GitHub (if enabled)
   - Other providers (configurable in Clerk)
4. After signup → redirected to `/hub`

### Sign In Flow

1. User visits `/sign-in` (or is redirected when accessing protected route)
2. Sees branded sign-in form
3. Signs in with chosen method
4. Redirected to `/hub`

### Signed In Experience

- User avatar in top-right corner
- Click avatar to see:
  - Manage account
  - Sign out
  - Other options
- All data (contacts, posts, health, projects) is user-specific
- Complete data isolation

### Sign Out

- Click avatar → "Sign Out"
- Redirected to landing page
- Session cleared

---

## Clerk Dashboard Configuration

### Recommended Settings

#### 1. Authentication Methods

Enable in **User & Authentication** → **Email, Phone, Username**:
- ✅ Email address (required)
- ✅ Password (recommended)
- ⬜ Phone number (optional)
- ⬜ Username (optional)

Enable in **Social Connections**:
- ✅ Google (recommended - easiest for users)
- ✅ GitHub (good for developers)
- ⬜ Others as needed

#### 2. Session Settings

In **Sessions**:
- Session duration: 7 days
- Inactive session lifetime: 1 hour
- ✅ Multi-session handling: Active

#### 3. Appearance

Customize in **Customization** → **Theme**:
- Already configured in code with your brand colors
- Primary color: `#C9A961` (amber)
- Background: `#FAF6EF` (linen)
- Border radius: `12px`

#### 4. Email Templates

Customize in **Emails**:
- Use your brand voice
- Add pocket watch logo
- Match warm, calm tone

---

## Data Migration

### For Existing Users

If you have existing data in Convex without `userId`:

1. **Backup existing data**
   ```bash
   # Export from Convex dashboard
   ```

2. **Clear tables or add userId**
   - Option A: Clear all data (if testing)
   - Option B: Manually assign userId to existing records

3. **For new production launch**
   - Deploy with auth from day 1
   - No migration needed

---

## Security Features

### Built-in Security

✅ **Session Management**
- Secure HTTP-only cookies
- Automatic token refresh
- CSRF protection

✅ **Password Security**
- bcrypt hashing
- Minimum password requirements
- Breach detection

✅ **Rate Limiting**
- Automatic brute-force protection
- Configurable limits

✅ **Email Verification**
- Optional email verification
- Magic link signin

✅ **Data Isolation**
- All queries filter by userId
- All mutations verify ownership
- Complete user data separation

### Additional Security (Optional)

Enable in Clerk dashboard:

⬜ **Two-Factor Authentication**
- SMS or TOTP
- Recommended for sensitive data

⬜ **Session Policies**
- Force re-authentication for sensitive actions
- IP-based restrictions

⬜ **Webhooks**
- User created/updated/deleted events
- Sync to external systems

---

## Webhooks (Advanced)

To sync Clerk events to your database:

1. **Create webhook endpoint**
   ```typescript
   // src/app/api/webhooks/clerk/route.ts
   import { Webhook } from 'svix'
   
   export async function POST(req: Request) {
     const payload = await req.json()
     // Handle user.created, user.updated, etc.
   }
   ```

2. **Configure in Clerk**
   - Go to **Webhooks**
   - Add endpoint: `https://yourdomain.com/api/webhooks/clerk`
   - Select events to receive

3. **Use Cases**
   - Create user profile in your database
   - Send welcome email
   - Initialize default data

---

## Testing

### Local Development

```bash
# Terminal 1: Convex dev
cd /Users/akio/personal_os/web
npx convex dev

# Terminal 2: Next.js dev
npm run dev
```

Test flows:
1. Sign up with test email
2. Verify email (if enabled)
3. Access protected routes
4. Create data (contacts, posts, health records)
5. Sign out
6. Sign in again
7. Verify data persists
8. Create second user
9. Verify data isolation (users can't see each other's data)

### Production Testing

After deploying:
1. Test signup flow
2. Test social login (if enabled)
3. Test sign out
4. Test accessing protected routes while signed out
5. Test data isolation (create second user, verify they don't see first user's data)
6. Test ownership verification (try to update another user's data)

---

## Deployment Checklist

### Vercel Environment Variables

Add these in Vercel dashboard (**Settings** → **Environment Variables**):

```bash
# Clerk
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_xxxxx
CLERK_SECRET_KEY=sk_live_xxxxx

# URLs (use your production domain)
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/hub
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/hub

# Convex (already set)
NEXT_PUBLIC_CONVEX_URL=https://astute-ant-253.convex.cloud

# Ollama (via ngrok)
NEXT_PUBLIC_OLLAMA_URL=https://your-ngrok-url.ngrok.app
```

### Convex Configuration

Run once:
```bash
npx convex dev --configure=clerk
```

This configures Convex to accept Clerk JWT tokens.

### Deploy Steps

```bash
# 1. Deploy schema to production
CONVEX_DEPLOYMENT=prod:astute-ant-253 npx convex deploy

# 2. Push to GitHub
git add .
git commit -m "Complete multi-user authentication with Clerk"
git push

# 3. Vercel auto-deploys on push
# Or manually: vercel --prod
```

---

## Troubleshooting

### "Not authenticated" errors

**Problem:** Queries failing with auth errors

**Solutions:**
1. Verify Clerk keys are set correctly in `.env.local`
2. Check Convex is configured for Clerk: `npx convex dev --configure=clerk`
3. Ensure middleware.ts is present
4. Clear browser cookies and sign in again
5. Check browser console for errors

### Redirect loops

**Problem:** Page keeps redirecting

**Solutions:**
1. Check middleware.ts `isPublicRoute` matcher
2. Verify sign-in/sign-up URLs match in env vars
3. Clear browser cache
4. Check Clerk dashboard for correct redirect URLs

### Social login not working

**Problem:** Google/GitHub login fails

**Solutions:**
1. Enable provider in Clerk dashboard
2. Configure OAuth redirect URLs
3. For production: Add production domain to allowed redirect URLs
4. Check provider credentials are correct

### User data not showing

**Problem:** Data created by user not appearing

**Solutions:**
1. Verify queries use `by_user` index
2. Check `identity.subject` matches `userId` in database
3. Use Convex dashboard to inspect data
4. Check browser console for errors
5. Verify user is authenticated

### Ownership verification errors

**Problem:** Cannot update/delete own records

**Solutions:**
1. Check userId matches between record and current user
2. Verify ownership check logic in mutations
3. Use Convex dashboard to inspect record userId field

---

## Cost

### Clerk Pricing

**Free Tier:**
- 10,000 monthly active users
- Unlimited applications
- All authentication methods
- Standard support

Perfect for Personal OS! Upgrade only if you exceed 10k users.

### Convex + Clerk

Convex authentication is free - no additional cost for using Clerk with Convex.

---

## Files Modified

### Authentication Core
- `/Users/akio/personal_os/web/middleware.ts` - Route protection
- `/Users/akio/personal_os/web/src/app/layout.tsx` - ClerkProvider
- `/Users/akio/personal_os/web/src/app/hub/layout.tsx` - Auth check
- `/Users/akio/personal_os/web/src/providers/ConvexClientProvider.tsx` - Convex + Clerk

### Auth Pages
- `/Users/akio/personal_os/web/src/app/sign-in/[[...sign-in]]/page.tsx`
- `/Users/akio/personal_os/web/src/app/sign-up/[[...sign-up]]/page.tsx`

### UI Components
- `/Users/akio/personal_os/web/src/components/layout/header.tsx` - UserButton
- `/Users/akio/personal_os/web/src/app/page.tsx` - Landing page redirect

### Database
- `/Users/akio/personal_os/web/convex/schema.ts` - Added userId fields & indexes
- `/Users/akio/personal_os/web/convex/business.ts` - ✅ Auth complete
- `/Users/akio/personal_os/web/convex/marketing.ts` - ✅ Auth complete
- `/Users/akio/personal_os/web/convex/wellbeing.ts` - ✅ Auth complete
- `/Users/akio/personal_os/web/convex/datascience.ts` - ✅ Auth complete

---

## Next Steps

1. ✅ Set up Clerk account → Get API keys
2. ✅ Add environment variables → `.env.local`
3. ✅ Configure Convex for Clerk → `npx convex dev --configure=clerk`
4. ✅ Test locally → `npm run dev`
5. ⬜ Deploy to production → Vercel + Convex
6. ⬜ Test production auth
7. ⬜ (Optional) Customize email templates
8. ⬜ (Optional) Enable 2FA
9. ⬜ (Optional) Set up webhooks

---

## Support

- **Clerk Docs:** https://clerk.com/docs
- **Convex Auth Docs:** https://docs.convex.dev/auth/clerk
- **Clerk Support:** support@clerk.com (responsive!)

---

## 🎉 SUCCESS!

**Your application now has production-grade, Facebook-level multi-user authentication!**

✅ Complete data isolation per user  
✅ Secure session management  
✅ Social login support  
✅ Ownership verification on all operations  
✅ Server-side auth checks  
✅ Client-side route protection  
✅ Branded sign-in/sign-up experience  

Each user gets their own private workspace with complete data separation. No user can see or modify another user's data.
