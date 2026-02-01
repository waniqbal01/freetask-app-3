# DigitalOcean App Platform - Quick Setup Guide

## Step 1: Create DigitalOcean Account

1. Go to [https://www.digitalocean.com](https://www.digitalocean.com)
2. Sign up for new account
3. **Tip**: Use a referral link to get **$200 credit** for 60 days (search "DigitalOcean referral")
4. Verify your email
5. Add payment method (required, but won't charge if using credit)

## Step 2: Create New App

1. After login, click **"Create"** → **"Apps"**
2. Or go directly to: https://cloud.digitalocean.com/apps/new

## Step 3: Connect GitHub Repository

1. Choose **"GitHub"** as source
2. Click **"Manage Access"** to authorize DigitalOcean
3. In the authorization window:
   - Select your account
   - Choose **"Only select repositories"**
   - Select: `freetask-app-3`
   - Click **"Install & Authorize"**

## Step 4: Configure Source

After authorization:

1. **Repository**: Select `freetask-app-3`
2. **Branch**: `main` (or your default branch)
3. **Source Directory**: `/freetask-api` ⚠️ **IMPORTANT**
4. **Autodeploy**: ✅ **Checked** (auto-deploy on git push)
5. Click **"Next"**

## Step 5: Configure App

### General Settings:

- **App Name**: `freetask-api` 
  - This creates URL: `https://freetask-api-[random].ondigitalocean.app`
  - You can customize later or add custom domain

### Edit Plan (before continuing):

Click **"Edit Plan"** and configure:

#### Resource Type:
- **Type**: Web Service ✅
- **HTTP Port**: `8080`
- **Health Check Path**: `/health`

#### Build Settings:
- **Build Command**: 
  ```bash
  npm ci --include=dev && npm run build
  ```
  
  Note: `npm ci --include=dev` ensures devDependencies (like TypeScript) are available during build.

- **Run Command**:
  ```bash
  npm exec prisma migrate deploy && npm run start:prod
  ```

#### Environment:
- **Node.js** (should be auto-detected)

#### Resource Size:
- **Plan**: Basic ($5/month)
- **Size**: 512 MB RAM / 1 vCPU
- ✅ This is sufficient to start, can scale later

Click **"Back"** to return to main configuration.

## Step 6: Add Environment Variables ⚠️ **CRITICAL**

Click **"Edit"** next to your app component, then scroll to **Environment Variables**.

Add these variables one by one:

### Required Environment Variables:

| Key | Value | Encrypt? |
|-----|-------|----------|
| `NODE_ENV` | `production` | No |
| `DATABASE_URL` | `postgresql://postgres.yviyhbzkmlttplszqfzo:Azli1970%21123@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres` | ✅ **YES** |
| `JWT_SECRET` | `1VZK6YbNyOe3RcMiXEg8DzILxHGCf49am0pvPUuh` | ✅ **YES** |
| `JWT_EXPIRES_IN` | `7d` | No |
| `JWT_REFRESH_EXPIRES_IN` | `7d` | No |
| `PORT` | `8080` | No |
| `ALLOWED_ORIGINS` | `*` | No |
| `TRUST_PROXY` | `true` | No |

### Billplz Variables (Get from your Render deployment):

| Key | Value | Encrypt? |
|-----|-------|----------|
| `BILLPLZ_API_KEY` | [Your Billplz API Key] | ✅ **YES** |
| `BILLPLZ_COLLECTION_ID` | [Your Collection ID] | No |
| `BILLPLZ_X_SIGNATURE` | [Your X Signature] | ✅ **YES** |

### Firebase Variables (if using push notifications):

| Key | Value | Encrypt? |
|-----|-------|----------|
| `FIREBASE_PROJECT_ID` | [Your Project ID] | No |

**Note**: 
- For `DATABASE_URL`, I'm using the **Connection Pooler** format with port **6543**
- Password `Azli1970!123` is URL-encoded as `Azli1970%21123`
- Mark sensitive values as "Encrypted" ✅

## Step 7: Configure Region

- **Region**: Select **Singapore** 🇸🇬
  - Closest to Malaysia
  - Same region as Supabase for low latency

## Step 8: Review & Create

1. Review all settings:
   - ✅ Source Directory: `/freetask-api`
   - ✅ Build Command: `npm install && npm run build`
   - ✅ Run Command: `npm exec prisma migrate deploy && npm run start:prod`
   - ✅ All environment variables added
   - ✅ Region: Singapore
   - ✅ Plan: Basic $5/month

2. Click **"Create Resources"**

3. **First deployment will start automatically!**

## Step 9: Monitor Deployment

1. You'll see **Build Logs** automatically
2. Watch for:
   - ✅ `npm install` success
   - ✅ `npm run build` success
   - ✅ **Prisma migrations deploying**
   - ✅ App starting with `npm run start:prod`

3. **Deployment time**: ~5-10 minutes for first deploy

### Expected Log Output:

```
Building... ✅
Running: npm install
...
Running: npm run build
...
Deploying...
Running: npm exec prisma migrate deploy
Prisma schema loaded from prisma/schema.prisma
Datasource "db": PostgreSQL database
✅ Migrations applied successfully
...
Running: npm run start:prod
Server listening on port 8080 ✅
```

## Step 10: Get Your App URL

After successful deployment:

1. Go to **Settings** → **Domains**
2. You'll see: `https://freetask-api-[random-id].ondigitalocean.app`
3. **Copy this URL** - you'll need it for:
   - Updating Flutter app
   - Updating Billplz webhooks

## Step 11: Test Your Deployment

```powershell
# Test health endpoint
curl https://freetask-api-[your-id].ondigitalocean.app/health

# Expected response: {"status":"ok"}
```

### Visit API Documentation:
Open browser: `https://freetask-api-[your-id].ondigitalocean.app/api`

You should see Swagger API documentation! 🎉

---

## Troubleshooting

### Build Failed?

**Check build logs for errors:**

1. **Common Issue**: Dependencies missing
   - Solution: Ensure `package.json` has all dependencies
   - Check Node.js version compatibility

2. **Migration Failed**:
   ```
   Error: Can't reach database server
   ```
   - Check `DATABASE_URL` is correct
   - Verify it's the **pooler** URL with port **6543**
   - Check password is URL-encoded

3. **Port Error**:
   ```
   Error: Port in use
   ```
   - Ensure `PORT=8080` in environment variables
   - Check run command uses correct port

### App Crashes After Deploy?

1. Check **Runtime Logs**: Apps → Your App → Runtime Logs
2. Look for error messages
3. Common issues:
   - Missing environment variables
   - Database connection failed
   - Invalid Prisma schema

### Need Help?

- View logs: Apps → freetask-api → Runtime Logs
- Rebuild: Apps → freetask-api → Actions → Force Rebuild

---

## Next Steps After Successful Deployment

1. ✅ **Note your app URL**
2. Update Billplz webhook
3. Update Flutter app `env.dart`
4. Test complete flow
5. Build new APK

---

**Ready to start?** Go to https://cloud.digitalocean.com/apps/new and follow the steps above! 🚀
