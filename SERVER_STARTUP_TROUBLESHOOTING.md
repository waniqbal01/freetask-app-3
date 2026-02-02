# Server Startup Troubleshooting Guide

## Current Status
✅ **Database Connection**: SUCCESS
- Prisma schema loaded
- Connected to Supabase PostgreSQL

❌ **Server Startup**: FAILED
- Error: `connection refused` on port 8080
- Health checks failing

---

## Need More Information

To troubleshoot, I need to see the **complete deployment logs**.

### How to Get Logs in DigitalOcean:

1. **Go to**: Your app in DigitalOcean
2. **Click**: "Runtime Logs" tab (not Build Logs)
3. **Look for**:
   - Prisma migration output
   - Any error messages
   - Server startup messages
   - Port binding messages

### What to Look For:

#### ✅ Success Pattern (if working):
```
Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database

🚀 Starting migration...
✔ Database migrations applied successfully

Server listening on port 8080
Application started successfully
```

#### ❌ Failure Patterns:

**Migration Failed:**
```
Error: Migration failed
P1001: Can't reach database
```

**Runtime Error:**
```
Error: Cannot find module 'xyz'
TypeError: ...
```

**Missing Environment Variable:**
```
Error: JWT_SECRET is not defined
Error: BILLPLZ_API_KEY is missing
```

**Port Already in Use:**
```
Error: listen EADDRINUSE: address already in use :::8080
```

---

## Common Issues & Fixes

### 1. Missing Environment Variables

**Check if all these are set:**
- ✅ NODE_ENV=production
- ✅ DATABASE_URL (encrypted)
- ✅ JWT_SECRET (encrypted)
- ✅ JWT_EXPIRES_IN=7d
- ✅ JWT_REFRESH_EXPIRES_IN=7d
- ✅ PORT=8080
- ✅ ALLOWED_ORIGINS=*
- ✅ TRUST_PROXY=true
- ✅ BILLPLZ_API_KEY (encrypted)
- ✅ BILLPLZ_COLLECTION_ID
- ✅ BILLPLZ_X_SIGNATURE (encrypted)

### 2. Migration Issues

If migrations fail:
- Check DATABASE_URL is correct
- Check database credentials
- Check if database allows connections

### 3. Billplz Service Initialization Error

**Common error:**
```
Error: BILLPLZ_API_KEY is not set!
```

**Fix:** Verify Billplz environment variables are set

### 4. Firebase Configuration (if using)

If you see Firebase-related errors and you're NOT using Firebase:
- This is okay, app should still start
- Can add dummy values or ignore

---

## Next Steps

**Please provide the full Runtime Logs**, specifically:

1. The section showing `npm exec prisma migrate deploy`
2. Any error messages after that
3. The section showing `npm run start:prod`
4. Any error messages during server startup

**To get logs:**
- DigitalOcean App → **Runtime Logs** tab
- Copy the entire log output
- Paste it here

This will help me identify exactly why the server isn't starting.

---

## Quick Check

While getting logs, also verify in DigitalOcean:

**Environment Variables** (Settings → your component):
- [ ] All variables listed above are present
- [ ] Sensitive ones are marked "Encrypted"
- [ ] No typos in variable names
- [ ] DATABASE_URL uses the pooler URL we just set

**Run Command** (Settings → your component):
```bash
npm exec prisma migrate deploy && npm run start:prod
```

Should be exactly like above.
