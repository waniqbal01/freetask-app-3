# Environment Variables for DigitalOcean App Platform

Copy and paste these into DigitalOcean App Platform Environment Variables section.

## Core Configuration

```
NODE_ENV=production
PORT=8080
ALLOWED_ORIGINS=*
TRUST_PROXY=true
```

## Database (Supabase - Transaction Pooler)
**⚠️ Mark as ENCRYPTED**

```
DATABASE_URL=postgresql://postgres.yviyhbzkmlttplszqfzo:Azli1970%21123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

Note: Transaction pooler with PgBouncer for optimal production performance.

## JWT Configuration
**⚠️ Mark JWT_SECRET as ENCRYPTED**

```
JWT_SECRET=1VZK6YbNyOe3RcMiXEg8DzILxHGCf49am0pvPUuh
JWT_EXPIRES_IN=7d
JWT_REFRESH_EXPIRES_IN=7d
```

## Billplz Configuration
**⚠️ Mark BILLPLZ_API_KEY and BILLPLZ_X_SIGNATURE as ENCRYPTED**

You need to get these from your current Render deployment or Billplz dashboard:

```
BILLPLZ_API_KEY=[YOUR_BILLPLZ_API_KEY]
BILLPLZ_COLLECTION_ID=[YOUR_COLLECTION_ID]
BILLPLZ_X_SIGNATURE=[YOUR_X_SIGNATURE]
```

### How to Get Billplz Credentials:

#### Option 1: From Current Render Deployment
1. Go to Render Dashboard
2. Select your `freetask-api` service
3. Go to Environment
4. Copy the values for:
   - BILLPLZ_API_KEY
   - BILLPLZ_COLLECTION_ID
   - BILLPLZ_X_SIGNATURE

#### Option 2: From Billplz Dashboard
1. Log in to https://www.billplz.com
2. Go to **Settings** → **API Credentials**
3. Copy:
   - **API Secret Key** (for BILLPLZ_API_KEY)
   - **Collection ID** (from Collections page)
   - **X Signature Key** (for BILLPLZ_X_SIGNATURE)

## Firebase Configuration (Optional - if using push notifications)

```
FIREBASE_PROJECT_ID=[YOUR_FIREBASE_PROJECT_ID]
```

If you have other Firebase env vars in your current deployment, copy them too.

---

## Summary Checklist

Before clicking "Create Resources" in DigitalOcean, ensure you have:

- ✅ `NODE_ENV=production`
- ✅ `DATABASE_URL` (with pooler URL, port 6543) **[ENCRYPTED]**
- ✅ `JWT_SECRET` **[ENCRYPTED]**
- ✅ `JWT_EXPIRES_IN=7d`
- ✅ `JWT_REFRESH_EXPIRES_IN=7d`
- ✅ `PORT=8080`
- ✅ `ALLOWED_ORIGINS=*`
- ✅ `TRUST_PROXY=true`
- ✅ `BILLPLZ_API_KEY` **[ENCRYPTED]**
- ✅ `BILLPLZ_COLLECTION_ID`
- ✅ `BILLPLZ_X_SIGNATURE` **[ENCRYPTED]**
- ✅ Firebase vars (if applicable)

---

## Important Notes

1. **Password in DATABASE_URL**: 
   - Original: `Azli1970!123`
   - URL-encoded: `Azli1970%21123` (! becomes %21)

2. **Connection Pooler**:
   - Port: **6543** (not 5432)
   - Better for production with multiple connections

3. **Mark as Encrypted**:
   - DATABASE_URL ✅
   - JWT_SECRET ✅
   - BILLPLZ_API_KEY ✅
   - BILLPLZ_X_SIGNATURE ✅

4. **Get Billplz Values**:
   - Can copy from existing Render deployment
   - Or get fresh from Billplz dashboard
