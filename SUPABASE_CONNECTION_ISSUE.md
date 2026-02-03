# Supabase Connection Troubleshooting

## Status
❌ **Cannot connect to Supabase** - All connection attempts failed

## Error Message
```
Tenant or user not found
```

## What I've Tried

Tested multiple connection formats:
- ✅ Different hostnames (aws-0, aws-1, db.xxx.supabase.co)
- ✅ Different ports (5432, 6543)
- ✅ Different usernames (postgres, postgres.yvjyhbzmnlttplszqfzo)
- ✅ URL-encoded password (Azli1970%21123)
- ✅ Connection string format vs individual parameters

All failed with same error.

## What This Means

The connection details from the screenshot may be incomplete or incorrect. Possible causes:
1. **Project Reference ID** might be different
2. **Hostname** format might be different for your project
3. **Database** might not be fully initialized yet
4. **Password** might need to be reset

## What You Need To Do

### Get Exact Connection String

1. Go to **Supabase Dashboard**: https://app.supabase.com
2. Select your **Freetask project**
3. Go to **Settings** → **Database**
4. Find "**Connection string**" section
5. Click "**URI**" tab
6. Click the **eye icon** to reveal password
7. **Copy the COMPLETE string**

It should look like:
```
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@[HOST]:[PORT]/postgres
```

### OR Get Individual Connection Info

If there's a "Connection Info" section, provide:
- **Host**: _________________
- **Database name**: postgres
- **Port**: 5432 or 6543
- **User**: _________________
- **Password**: Azli1970!123 (confirm this is correct)

## Alternative: Use Supabase Studio

Instead of command-line migration, kita boleh guna **Supabase Studio** (web interface):
1. Export data from Render ke CSV/SQL file
2. Import manually via Supabase Studio Table Editor

Tapi cara ni lebih slow untuk 16 tables.

## Ready to Proceed

Once anda berikan exact connection details, saya akan:
1. ✅ Test connection
2. ✅ Run full migration (16 tables)
3. ✅ Verify data integrity
4. ✅ Update .env file
5. ✅ Test API
