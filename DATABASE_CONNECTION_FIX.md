# Database Connection Error Fix

## Problem
Prisma migrations failed with:
```
Error: Schema engine error:
FATAL: Tenant or user not found
```

## Root Cause
The connection pooler URL format is incorrect. I created it manually but the format doesn't match what Supabase expects.

---

## Solution: Get Correct Connection String from Supabase

### Option 1: Use Transaction Pooler (Recommended for Production)

1. **Go to Supabase Dashboard**: https://supabase.com/dashboard
2. **Select your project**: freetask-db
3. **Go to**: Settings → Database
4. **Scroll to**: "Connection Pooling" section
5. **Select Mode**: Transaction
6. **Copy the URI** - should look like:
   ```
   postgresql://postgres.yviyhbzkmlttplszqfzo:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
   ```

7. **Replace** `[YOUR-PASSWORD]` with URL-encoded password: `Azli1970%21123`
8. **Paste the complete string here**

### Option 2: Use Direct Connection (Simpler, May Work)

Use the original connection string you provided but with password URL-encoded:

```
postgresql://postgres:Azli1970%21123@db.yviyhbzkmlttplszqfzo.supabase.co:5432/postgres
```

**This is simpler and should work for now.** You can optimize with pooler later.

---

## Quick Fix Steps

### For Option 2 (Direct Connection - Fastest):

1. **Go to DigitalOcean** → Your App → **Settings** → **Environment Variables**
2. **Find**: `DATABASE_URL`
3. **Edit** and change to:
   ```
   postgresql://postgres:Azli1970%21123@db.yviyhbzkmlttplszqfzo.supabase.co:5432/postgres
   ```
4. **Save**
5. App will auto-redeploy

### For Option 1 (Transaction Pooler - Better for Production):

1. Get the **exact** connection string from Supabase dashboard (Connection Pooling section)
2. Make sure to:
   - Replace password placeholder with: `Azli1970%21123`
   - Keep the `?pgbouncer=true` parameter if it exists
3. Update in DigitalOcean environment variables
4. Redeploy

---

## Recommended Approach

**Start with Option 2 (Direct Connection)** to get it working quickly:
```
postgresql://postgres:Azli1970%21123@db.yviyhbzkmlttplszqfzo.supabase.co:5432/postgres
```

Once everything works, you can optimize by switching to Connection Pooler if needed.

---

## After Updating DATABASE_URL

Monitor the deployment logs:
- ✅ Prisma should connect successfully
- ✅ Migrations should run
- ✅ Server should start on port 8080
- ✅ Health check should pass

---

**Action: Go update DATABASE_URL in DigitalOcean now with the direct connection string!**
