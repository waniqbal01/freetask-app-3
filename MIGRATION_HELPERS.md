# Migration Helper Scripts

## Quick Setup Commands

### Generate JWT Secret
```powershell
# Generates a random 64-character secret
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
```

### Test Database Connection
```powershell
# Set environment variable (replace with your actual Supabase URL)
$env:DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Test connection
cd freetask-api
npm exec prisma db pull
```

### Run Migrations Locally (Testing)
```powershell
# Make sure DATABASE_URL is set to Supabase
$env:DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Run migrations
npm exec prisma migrate deploy

# Verify tables
npm exec prisma studio
```

### Export Data from Current Database (if needed)
```powershell
# If you need to backup current Render database
$env:SOURCE_DB="[YOUR_RENDER_DATABASE_URL]"
pg_dump $env:SOURCE_DB > render_backup.sql

# Import to Supabase
$env:DEST_DB="[YOUR_SUPABASE_DATABASE_URL]"
psql $env:DEST_DB < render_backup.sql
```

### Test API Health
```powershell
# Test local
curl http://localhost:4000/health

# Test production (after deployment)
curl https://freetask-api-xxxxx.ondigitalocean.app/health
```

### Build and Test Locally
```powershell
cd freetask-api

# Install dependencies
npm install

# Build
npm run build

# Test production build locally
npm run start:prod
```

## Deployment Checklist

### ✅ Pre-Deployment
- [ ] Create Supabase project
- [ ] Get Supabase DATABASE_URL (with pooling)
- [ ] Generate new JWT_SECRET
- [ ] Prepare Billplz credentials
- [ ] Test database connection locally

### ✅ DigitalOcean Setup
- [ ] Create DigitalOcean account
- [ ] Connect GitHub repository
- [ ] Configure build settings
- [ ] Add all environment variables
- [ ] Set up health checks
- [ ] Deploy app

### ✅ Post-Deployment
- [ ] Verify migrations ran successfully
- [ ] Test `/health` endpoint
- [ ] Test `/api` documentation
- [ ] Update Billplz webhook URL
- [ ] Update Flutter app `env.dart`
- [ ] Test complete user flow
- [ ] Monitor logs for errors

### ✅ Flutter App Update
- [ ] Update `env.dart` with new URL
- [ ] Test in development
- [ ] Build new APK
- [ ] Test APK on device
- [ ] Deploy to production

### ✅ Cleanup (After Verification)
- [ ] Monitor DigitalOcean for 24-48 hours
- [ ] Confirm all features working
- [ ] Decommission Render service
- [ ] Update any remaining documentation

## Environment Variables Reference

| Variable | Where to Get | Example |
|----------|--------------|---------|
| `DATABASE_URL` | Supabase Dashboard → Settings → Database | `postgresql://postgres...` |
| `JWT_SECRET` | Generate with PowerShell command above | `aB3dE5fG7...` |
| `BILLPLZ_API_KEY` | Billplz Dashboard → Settings | `abc123...` |
| `BILLPLZ_COLLECTION_ID` | Billplz Dashboard → Collections | `xyz789...` |
| `BILLPLZ_X_SIGNATURE` | Billplz Dashboard → Settings | `S-signature...` |

## Troubleshooting Common Issues

### Database Connection Failed
```
Error: Can't reach database server
```
**Fix**: 
- Check DATABASE_URL is correct
- Verify Supabase project is active
- Check network connectivity

### Migration Failed
```
Error: Migration engine error
```
**Fix**:
- Check if schema has conflicts
- Try running migrations manually
- Check database logs in Supabase

### Build Failed on DigitalOcean
```
Error: npm install failed
```
**Fix**:
- Check `package.json` for syntax errors
- Verify Node.js version compatibility
- Check build logs for specific error

### App Crashes on Start
```
Error: Application error
```
**Fix**:
- Verify all environment variables are set
- Check runtime logs
- Ensure PORT is set to 8080
- Verify DATABASE_URL is accessible

### Billplz Webhook Not Working
```
Payment status not updating
```
**Fix**:
- Verify webhook URL is updated in Billplz
- Check webhook endpoint is accessible
- Monitor logs for webhook requests
- Verify X-Signature is correct
