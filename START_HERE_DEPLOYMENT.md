# 🚀 READY TO DEPLOY - Quick Start Guide

## ✅ What's Been Done

1. ✅ Supabase database created
2. ✅ Connection string obtained
3. ✅ JWT secret generated
4. ✅ All configuration files prepared
5. ✅ Migration strategy decided (deploy-time migrations)

---

## 📋 What You Need Before Starting

### 1. Supabase Details (READY)
- ✅ Database URL: `postgresql://postgres.yviyhbzkmlttplszqfzo:Azli1970%21123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres`

### 2. JWT Secret (READY)
- ✅ Secret: `1VZK6YbNyOe3RcMiXEg8DzILxHGCf49am0pvPUuh`

### 3. Billplz Credentials (NEED TO GET)
You need to get these from Render:
- ⚠️ `BILLPLZ_API_KEY`
- ⚠️ `BILLPLZ_COLLECTION_ID`
- ⚠️ `BILLPLZ_X_SIGNATURE`

**How to get**: Go to https://dashboard.render.com → Your service → Environment tab → Copy the values

---

## 🎯 DEPLOYMENT STEPS (Follow in Order)

### Step 1: Get Billplz Credentials (5 minutes)

1. Go to https://dashboard.render.com
2. Click on your `freetask-api` service
3. Click **"Environment"** tab
4. Copy these 3 values:
   ```
   BILLPLZ_API_KEY=_______________
   BILLPLZ_COLLECTION_ID=_______________
   BILLPLZ_X_SIGNATURE=_______________
   ```
5. **Keep them ready** - you'll paste them into DigitalOcean

### Step 2: Create DigitalOcean Account (5 minutes)

1. Go to https://www.digitalocean.com
2. Sign up (Tip: Search for "DigitalOcean referral $200" for free credits)
3. Verify email
4. Add payment method

### Step 3: Deploy to DigitalOcean (15 minutes)

**Follow the detailed guide**: [`DIGITALOCEAN_QUICK_SETUP.md`](file:///C:/Users/USER/freetask-app-3/DIGITALOCEAN_QUICK_SETUP.md)

**Quick Summary:**

1. **Create App**: https://cloud.digitalocean.com/apps/new
2. **Connect GitHub**: Select `freetask-app-3` repository
3. **Configure Source**:
   - Source Directory: `/freetask-api` ⚠️
   - Branch: `main`
   - Autodeploy: ✅ Enabled

4. **Configure Build**:
   - Build Command: `npm ci --include=dev && npm run build`
   - Run Command: `npm exec prisma migrate deploy && npm run start:prod`
   - HTTP Port: `8080`
   - Health Check: `/health`

5. **Add Environment Variables** (Copy from [`DIGITALOCEAN_ENV_VARS.md`](file:///C:/Users/USER/freetask-app-3/DIGITALOCEAN_ENV_VARS.md)):
   
   **Core:**
   ```
   NODE_ENV=production
   PORT=8080
   ALLOWED_ORIGINS=*
   TRUST_PROXY=true
   ```

   **Database (ENCRYPT ✅):**
   ```
   DATABASE_URL=postgresql://postgres.yviyhbzkmlttplszqfzo:Azli1970%21123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
   ```
   
   Note: Using Supabase connection pooler (port 6543) with pgbouncer for optimal performance.

   **JWT (ENCRYPT ✅):**
   ```
   JWT_SECRET=1VZK6YbNyOe3RcMiXEg8DzILxHGCf49am0pvPUuh
   JWT_EXPIRES_IN=7d
   JWT_REFRESH_EXPIRES_IN=7d
   ```

   **Billplz (from Render - ENCRYPT API_KEY and X_SIGNATURE_KEY ✅):**
   ```
   BILLPLZ_API_KEY=[paste from Render]
   BILLPLZ_COLLECTION_ID=[paste from Render]
   BILLPLZ_X_SIGNATURE_KEY=[paste from Render]
   ```
   
   **IMPORTANT**: Variable name is `BILLPLZ_X_SIGNATURE_KEY` (with `_KEY` suffix!)

6. **Select Region**: Singapore 🇸🇬

7. **Select Plan**: Basic ($5/month)

8. **Click "Create Resources"** 🚀

### Step 4: Monitor Deployment (5-10 minutes)

Watch the **Build Logs** for:
- ✅ Dependencies installing
- ✅ TypeScript compiling
- ✅ **Prisma migrations running** 👈 IMPORTANT!
- ✅ Server starting on port 8080

### Step 5: Get Your App URL

After deployment succeeds:
1. Go to **Settings** → **Domains**
2. Copy URL: `https://freetask-api-xxxxx.ondigitalocean.app`
3. **Test it**: Open in browser and add `/health`
   - Should return: `{"status":"ok"}`

### Step 6: Update Billplz Webhook

1. Go to https://www.billplz.com
2. Login → Settings → Webhooks
3. Update callback URL:
   - **Old**: `https://freetask-api.onrender.com/billplz/webhook`
   - **New**: `https://freetask-api-xxxxx.ondigitalocean.app/billplz/webhook`
   - (Replace `xxxxx` with your actual app ID)
4. Save

### Step 7: Update Flutter App

Edit this file: `freetask_app/lib/core/env.dart`

Change line 11:
```dart
// FROM:
return 'https://freetask-api.onrender.com';

// TO:
return 'https://freetask-api-xxxxx.ondigitalocean.app';
```

### Step 8: Test Everything

1. **Test API**:
   ```powershell
   curl https://freetask-api-xxxxx.ondigitalocean.app/health
   curl https://freetask-api-xxxxx.ondigitalocean.app/api
   ```

2. **Test Flutter App**:
   ```powershell
   cd freetask_app
   flutter run
   ```
   - Test login
   - Test creating job
   - Test payment flow
   - Test chat

3. **Build New APK**:
   ```powershell
   flutter build apk --release
   ```

---

## 📚 Reference Documents

All guides are ready in your project:

1. **[DIGITALOCEAN_QUICK_SETUP.md](file:///C:/Users/USER/freetask-app-3/DIGITALOCEAN_QUICK_SETUP.md)** - Detailed step-by-step setup
2. **[DIGITALOCEAN_ENV_VARS.md](file:///C:/Users/USER/freetask-app-3/DIGITALOCEAN_ENV_VARS.md)** - All environment variables
3. **[GET_BILLPLZ_CREDENTIALS.md](file:///C:/Users/USER/freetask-app-3/GET_BILLPLZ_CREDENTIALS.md)** - How to get Billplz details
4. **[MIGRATION_HELPERS.md](file:///C:/Users/USER/freetask-app-3/MIGRATION_HELPERS.md)** - Helper commands
5. **[SUPABASE_CONNECTION_TROUBLESHOOTING.md](file:///C:/Users/USER/freetask-app-3/SUPABASE_CONNECTION_TROUBLESHOOTING.md)** - Connection issues

---

## ⚠️ Important Notes

1. **Database Migrations**: Will run automatically on first deployment via the run command
2. **SSL Certificate**: DigitalOcean provides free SSL automatically
3. **Monitoring**: Check runtime logs in DigitalOcean dashboard after deploy
4. **Billplz Webhook**: MUST update after deployment or payments won't work
5. **Keep Render Running**: Don't delete Render service until you confirm everything works on DigitalOcean

---

## 🆘 Need Help?

If you encounter any issues:
1. Check the **Runtime Logs** in DigitalOcean
2. Verify all environment variables are set correctly
3. Ensure DATABASE_URL uses port **6543** (pooler)
4. Check build logs for migration errors

Common error solutions in [`MIGRATION_HELPERS.md`](file:///C:/Users/USER/freetask-app-3/MIGRATION_HELPERS.md)

---

## ✅ Success Checklist

After deployment, verify:
- [ ] Health endpoint returns `{"status":"ok"}`
- [ ] API docs accessible at `/api`
- [ ] Database has all tables (check Supabase dashboard)
- [ ] Flutter app can login
- [ ] Can create jobs
- [ ] Payments work (test with real Billplz)
- [ ] Chat works
- [ ] Notifications work

---

**🎉 Ready? Start with Step 1 - Get your Billplz credentials from Render!**

Then follow the guide in [`DIGITALOCEAN_QUICK_SETUP.md`](file:///C:/Users/USER/freetask-app-3/DIGITALOCEAN_QUICK_SETUP.md)
