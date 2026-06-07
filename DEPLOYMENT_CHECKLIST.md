# 🚀 Deployment Checklist

## Pre-Deployment Checklist

### ✅ Code Implementation (COMPLETE)

- [x] Authentication infrastructure
- [x] Middleware setup
- [x] Sign-in/sign-up pages
- [x] Database schema with userId
- [x] All Convex functions updated with auth
- [x] Ownership verification on mutations
- [x] User-scoped queries
- [x] Branded UI components

### 🔧 Configuration Needed

#### 1. Clerk Setup (5 minutes)

**Steps:**
1. Go to https://clerk.com and create account
2. Create a new application
3. Enable authentication methods:
   - ✅ Email + Password (recommended)
   - ✅ Google (optional, recommended for ease)
   - ✅ GitHub (optional, good for developers)
4. Go to **API Keys** and copy:
   - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
   - `CLERK_SECRET_KEY`

#### 2. Local Environment Variables (2 minutes)

Create `/Users/akio/personal_os/web/.env.local`:

```bash
# Clerk Authentication
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxx
CLERK_SECRET_KEY=sk_test_xxxxxxxxxxxxx

# Clerk URLs
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/hub
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/hub

# Convex
NEXT_PUBLIC_CONVEX_URL=https://astute-ant-253.convex.cloud

# Ollama (via ngrok)
NEXT_PUBLIC_OLLAMA_URL=https://your-ngrok-url.ngrok.app
```

#### 3. Configure Convex for Clerk (1 minute)

```bash
cd /Users/akio/personal_os/web
npx convex dev --configure=clerk
```

This will:
- Add Clerk as auth provider in Convex
- Generate necessary configuration
- Enable JWT validation

#### 4. Deploy Schema to Production (1 minute)

```bash
cd /Users/akio/personal_os/web
CONVEX_DEPLOYMENT=prod:astute-ant-253 npx convex deploy
```

This deploys the updated schema with userId fields and indexes.

#### 5. Test Locally (5 minutes)

```bash
# Terminal 1: Convex dev
cd /Users/akio/personal_os/web
npx convex dev

# Terminal 2: Next.js dev
npm run dev
```

**Test flow:**
1. Visit http://localhost:3000
2. Click "Sign Up"
3. Create test account
4. Verify redirect to /hub
5. Create some test data (contact, post, etc.)
6. Sign out
7. Sign in again
8. Verify data persists
9. Create second test account
10. Verify data isolation (no access to first user's data)

#### 6. Vercel Environment Variables (2 minutes)

Go to Vercel dashboard → Your Project → Settings → Environment Variables

Add:

```bash
# Clerk (use LIVE keys for production!)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_xxxxx
CLERK_SECRET_KEY=sk_live_xxxxx

# Clerk URLs
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/hub
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/hub

# Convex (already set)
NEXT_PUBLIC_CONVEX_URL=https://astute-ant-253.convex.cloud

# Ollama (via ngrok)
NEXT_PUBLIC_OLLAMA_URL=https://your-ngrok-url.ngrok.app
```

**Important:** Use `pk_live_` and `sk_live_` keys for production, not test keys!

#### 7. Deploy to Vercel (1 minute)

```bash
cd /Users/akio/personal_os/web
git add .
git commit -m "Complete multi-user authentication implementation"
git push
```

Vercel will auto-deploy. Or manually:

```bash
vercel --prod
```

#### 8. Production Testing (5 minutes)

Visit your production URL (e.g., https://web-iota-eight-97.vercel.app)

**Test flow:**
1. Test sign up flow
2. Test sign in flow
3. Test data creation
4. Test sign out
5. Test accessing /hub while signed out (should redirect)
6. Create second user
7. Verify complete data isolation
8. Test social login (if enabled)

---

## Quick Commands Reference

```bash
# Configure Convex for Clerk
npx convex dev --configure=clerk

# Deploy schema to production
CONVEX_DEPLOYMENT=prod:astute-ant-253 npx convex deploy

# Start local development
npm run dev

# Deploy to Vercel
git push  # Auto-deploy
# or
vercel --prod  # Manual deploy
```

---

## Estimated Time

- **Clerk setup:** 5 minutes
- **Local configuration:** 10 minutes
- **Local testing:** 5 minutes
- **Production deployment:** 10 minutes
- **Total:** ~30 minutes

---

## Post-Deployment

### Optional Enhancements

1. **Customize Clerk appearance** (10 minutes)
   - Go to Clerk dashboard → Customization → Theme
   - Match your brand colors (already done in code)

2. **Customize email templates** (15 minutes)
   - Go to Clerk dashboard → Emails
   - Add pocket watch logo
   - Match your tone

3. **Enable Two-Factor Authentication** (5 minutes)
   - Go to Clerk dashboard → User & Authentication → Multi-factor
   - Enable TOTP or SMS

4. **Set up webhooks** (optional)
   - Sync user events to external systems
   - Send welcome emails
   - Initialize default data

### Monitoring

Check these regularly:

1. **Clerk Dashboard**
   - Active users
   - Failed login attempts
   - Session analytics

2. **Convex Dashboard**
   - Query performance
   - Database size
   - Error logs

3. **Vercel Analytics**
   - Page views
   - Performance metrics
   - Error tracking

---

## Troubleshooting

If issues occur, check:

1. **Environment variables** are set correctly in Vercel
2. **Convex is configured** for Clerk: `npx convex dev --configure=clerk`
3. **Schema is deployed** to production: `CONVEX_DEPLOYMENT=prod:astute-ant-253 npx convex deploy`
4. **Clerk keys** are production keys (`pk_live_`, not `pk_test_`)
5. **Browser console** for client-side errors
6. **Vercel logs** for server-side errors

---

## Success Criteria

Your deployment is successful when:

✅ Users can sign up  
✅ Users can sign in  
✅ Users are redirected to /hub after auth  
✅ Unauthenticated users cannot access /hub  
✅ Users can create data (contacts, posts, etc.)  
✅ Users can only see their own data  
✅ Users cannot see or modify other users' data  
✅ Sign out works and redirects to landing page  
✅ Social login works (if enabled)  

---

## Support Resources

- **AUTH_SETUP.md** - Comprehensive authentication documentation
- **Clerk Docs:** https://clerk.com/docs
- **Convex Auth Docs:** https://docs.convex.dev/auth/clerk
- **Clerk Support:** support@clerk.com

---

## 🎉 You're Ready!

Your application is production-ready with enterprise-grade authentication. Follow the checklist above to deploy.
