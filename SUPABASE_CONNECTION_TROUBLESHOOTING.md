# Supabase Connection Troubleshooting

## Issue
Cannot connect to Supabase database from local machine. Error: P1001 (Cannot reach database server)

## Possible Causes
1. **Firewall blocking port 5432**
2. **Network restrictions**
3. **Need to use connection pooler instead**

## Solutions

### Option 1: Use Connection Pooler (Recommended for Production)

1. Go to **Supabase Dashboard** → **Settings** → **Database**
2. Scroll to **Connection Pooling** section
3. Select:
   - Mode: **Transaction**
   - Port will be: **6543** (not 5432)
4. Copy the connection string format:
   ```
   postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
   ```

For your project, it should look like:
```
postgresql://postgres.yviyhbzkmlttplszqfzo:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
```

### Option 2: Run Migrations via Supabase SQL Editor

If local connection fails, we can generate SQL and run it directly in Supabase:

1. **Generate migration SQL locally:**
   ```powershell
   cd freetask-api
   npm exec prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script > migration.sql
   ```

2. **Run in Supabase:**
   - Go to Supabase Dashboard → SQL Editor
   - Paste the generated SQL
   - Execute

### Option 3: Use DigitalOcean to Run Migrations

Deploy to DigitalOcean first, then migrations will run automatically there (no local connection needed).

## Next Steps

Please try:
1. Get the **Connection Pooling** string from Supabase
2. Or, we can proceed directly to DigitalOcean deployment
3. Migrations will run automatically on first deployment

## Connection String Format Reference

**Direct Connection** (port 5432):
```
postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

**Connection Pooling** (port 6543) - **Recommended for Production**:
```
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres
```

Note: Password special characters need URL encoding:
- `!` = `%21`
- `@` = `%40`
- `#` = `%23`
- etc.
