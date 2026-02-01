# DigitalOcean + Supabase Deployment Guide

## Overview

This guide walks you through deploying the Freetask API to DigitalOcean App Platform with Supabase as the PostgreSQL database.

---

## Step 1: Setup Supabase Database

### 1.1 Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or log in
3. Click **"New Project"**
4. Fill in project details:
   - **Name**: `freetask-db` (or your preferred name)
   - **Database Password**: Generate a strong password (save it securely!)
   - **Region**: **Southeast Asia (Singapore)** 🇸🇬
   - **Pricing Plan**: Free tier (can upgrade later)
5. Click **"Create new project"**
6. Wait 2-3 minutes for provisioning

### 1.2 Get Database Connection String

1. In your Supabase project dashboard, go to:
   - **Settings** (gear icon on left sidebar)
   - **Database**
   - Scroll to **Connection String** section

2. Copy the **Connection string** (URI format):
   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
   ```

3. Replace `[YOUR-PASSWORD]` with your actual database password

4. **Important**: For production, use the **Connection pooling** string:
   - Mode: **Transaction**
   - Port: **6543** (note: different from direct connection)
   ```
   postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
   ```

### 1.3 Test Database Connection (Optional but Recommended)

On your local machine:

```powershell
# Set the DATABASE_URL temporarily
$env:DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres"

# Navigate to API directory
cd freetask-api

# Test Prisma connection
npm exec prisma db pull

# If successful, you'll see: "Introspected 0 models and wrote them..."
```

---

## Step 2: Setup DigitalOcean App Platform

### 2.1 Create DigitalOcean Account

1. Go to [https://www.digitalocean.com](https://www.digitalocean.com)
2. Sign up (tip: use referral link for $200 free credit for 60 days)
3. Complete account verification

### 2.2 Connect GitHub Repository

1. In DigitalOcean dashboard, go to **Apps** → **Create App**
2. Choose **GitHub** as source
3. Click **"Manage Access"** to authorize DigitalOcean
4. Select your `freetask-app-3` repository
5. Click **Next**

### 2.3 Configure App Settings

#### Source Settings:
- **Branch**: `main` (or your default branch)
- **Source Directory**: `/freetask-api`
- **Autodeploy**: ✅ Enabled (deploys on git push)

#### App Settings:
- **App Name**: `freetask-api` (will create URL: freetask-api-xxxxx.ondigitalocean.app)
- **Region**: **Singapore** (closest to Malaysia/Supabase)
- **Type**: **Web Service**

#### Build Configuration:
- **Environment**: Node.js
- **Build Command**: 
  ```bash
  npm install && npm run build
  ```
- **Run Command**:
  ```bash
  npm exec prisma migrate deploy && npm run start:prod
  ```

#### Resource Size:
- Start with **Basic** plan ($5/month)
- 512 MB RAM / 1 vCPU
- Can scale up later if needed

### 2.4 Configure Environment Variables

In the **Environment Variables** section, add these:

| Key | Value | Encrypted |
|-----|-------|-----------|
| `NODE_ENV` | `production` | No |
| `DATABASE_URL` | `postgresql://postgres.[REF]:[PASS]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres` | ✅ Yes |
| `JWT_SECRET` | Generate random 32+ char string | ✅ Yes |
| `JWT_EXPIRES_IN` | `7d` | No |
| `JWT_REFRESH_EXPIRES_IN` | `7d` | No |
| `PORT` | `8080` | No |
| `ALLOWED_ORIGINS` | `*` | No |
| `TRUST_PROXY` | `true` | No |
| `BILLPLZ_API_KEY` | Your Billplz API key | ✅ Yes |
| `BILLPLZ_COLLECTION_ID` | Your collection ID | No |
| `BILLPLZ_X_SIGNATURE` | Your X signature key | ✅ Yes |

**To generate JWT_SECRET:**
```powershell
# On Windows PowerShell:
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

### 2.5 Configure Health Checks

- **Health Check Path**: `/health`
- **Port**: `8080`

### 2.6 Review and Create

1. Review all settings
2. Click **"Create Resources"**
3. Wait for first deployment (~5-10 minutes)
4. Monitor build logs for any errors

### 2.7 Get Your App URL

After deployment:
- Your app will be available at: `https://freetask-api-xxxxx.ondigitalocean.app`
- Test health endpoint: `https://freetask-api-xxxxx.ondigitalocean.app/health`

---

## Step 3: Run Database Migrations

### Option A: Automatic (Recommended)

The migrations run automatically on deployment via the run command:
```bash
npm exec prisma migrate deploy && npm run start:prod
```

Check the deployment logs to verify migrations ran successfully.

### Option B: Manual (if needed)

If you need to run migrations manually:

1. Go to **Console** tab in your DigitalOcean app
2. Run:
   ```bash
   npm exec prisma migrate deploy
   ```

---

## Step 4: Update Billplz Webhooks

**Important**: Update your Billplz callback URLs to point to the new server!

1. Log in to [Billplz Dashboard](https://www.billplz.com)
2. Go to **Settings** → **Webhooks** (or Account Settings)
3. Update callback URL:
   - **Old**: `https://freetask-api.onrender.com/billplz/webhook`
   - **New**: `https://freetask-api-xxxxx.ondigitalocean.app/billplz/webhook`
4. Save changes

---

## Step 5: Update Flutter App Configuration

Update the API base URL in your Flutter app:

**File**: `freetask_app/lib/core/env.dart`

```dart
class Env {
  static String get defaultApiBaseUrl {
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    // DigitalOcean Production Backend
    return 'https://freetask-api-xxxxx.ondigitalocean.app';
  }
}
```

Replace `xxxxx` with your actual app URL.

---

## Step 6: Testing & Verification

### 6.1 Test API Endpoints

```powershell
# Health check
curl https://freetask-api-xxxxx.ondigitalocean.app/health

# API documentation
# Visit: https://freetask-api-xxxxx.ondigitalocean.app/api
```

### 6.2 Test with Flutter App

1. Update `env.dart` with new URL
2. Run app: `flutter run`
3. Test key flows:
   - ✅ User registration
   - ✅ Login
   - ✅ Browse services
   - ✅ Create job
   - ✅ Payment flow
   - ✅ Chat
   - ✅ Notifications

### 6.3 Monitor Logs

In DigitalOcean dashboard:
- Go to your app → **Runtime Logs**
- Monitor for errors
- Check request/response patterns

---

## Step 7: Custom Domain (Optional)

### Add Custom Domain

1. In DigitalOcean app settings, go to **Domains**
2. Click **"Add Domain"**
3. Enter your domain: `api.freetask.com`
4. Add DNS records in your domain provider:
   ```
   Type: CNAME
   Name: api
   Value: freetask-api-xxxxx.ondigitalocean.app
   TTL: 3600
   ```
5. Wait for DNS propagation (~5-60 minutes)
6. DigitalOcean will automatically provision SSL certificate

### Update After Custom Domain

If you add a custom domain, update:
1. `env.dart` in Flutter app
2. Billplz webhook URL
3. Any other integrations

---

## Troubleshooting

### Build Fails

- Check build logs in DigitalOcean
- Verify Node.js version compatibility
- Ensure all dependencies in `package.json`

### Database Connection Issues

- Verify DATABASE_URL is correct
- Check Supabase connection pooling settings
- Ensure IP allowlisting (Supabase allows all by default)

### Migration Errors

- Check Prisma schema syntax
- Verify DATABASE_URL has correct permissions
- Run migrations manually via console

### App Crashes

- Check runtime logs
- Verify all environment variables are set
- Check database connectivity
- Verify PORT is set to 8080

---

## Performance Optimization

### 1. Enable Connection Pooling

Already configured by using Supabase pooler URL (port 6543).

### 2. Scale Resources

If app is slow:
- Upgrade to Professional plan ($12/month)
- 1 GB RAM / 1 vCPU

### 3. Add CDN (Optional)

For static assets:
- DigitalOcean Spaces + CDN
- Cloudflare in front

---

## Cost Estimation

| Service | Plan | Monthly Cost |
|---------|------|--------------|
| Supabase Database | Free tier | $0 (8 GB storage, 500 MB database) |
| Supabase (Paid) | Pro | $25 (if you exceed free tier) |
| DigitalOcean App Platform | Basic | $5 |
| DigitalOcean App Platform | Professional | $12 |

**Total**: $5-37/month depending on usage

---

## Backup & Maintenance

### Database Backups

Supabase Free Tier:
- 7 days of backup history
- Can manually export via dashboard

For critical production:
- Upgrade to Supabase Pro for 14 days backup
- Or set up automated `pg_dump` backups

### App Monitoring

- Enable DigitalOcean monitoring
- Set up alerts for:
  - High CPU/memory usage
  - App crashes
  - Response time degradation

---

## Migration from Render

### Zero-Downtime Migration

1. Set up DigitalOcean completely first
2. Test thoroughly
3. Update DNS/config to point to DigitalOcean
4. Keep Render running for 24-48 hours as backup
5. Monitor for issues
6. Decommission Render after confirmation

### Data Migration (if needed)

If you have existing data on Render database:

```powershell
# Export from Render
pg_dump $RENDER_DATABASE_URL > backup.sql

# Import to Supabase
psql $SUPABASE_DATABASE_URL < backup.sql
```

---

## Support & Resources

- **DigitalOcean Docs**: https://docs.digitalocean.com/products/app-platform/
- **Supabase Docs**: https://supabase.com/docs
- **Prisma Docs**: https://www.prisma.io/docs

---

**Last Updated**: 2026-02-01
