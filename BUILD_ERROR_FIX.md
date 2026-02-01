# Build Error Fix - TypeScript Compiler Not Found

## Problem
Build failed with error:
```
sh: 1: tsc: not found
building: exit status 127
ERROR: failed to build: exit status 1
```

## Root Cause
DigitalOcean buildpack prunes `devDependencies` before running the custom build command. TypeScript (`tsc`) is a devDependency, so it gets removed before the build runs.

## Solution
Update the **Build Command** in DigitalOcean to reinstall dependencies including dev packages.

---

## Fix Steps

### Option 1: Update Build Command (Recommended)

1. Go to your DigitalOcean App
2. Click **Settings** → **Components** → Edit your component
3. Scroll to **Build Command**
4. Change from:
   ```bash
   npm install && npm run build
   ```
   
   To:
   ```bash
   npm ci --include=dev && npm run build
   ```

5. **Save** and **Redeploy**

**Why `npm ci --include=dev`?**
- `npm ci` is faster and more reliable for production builds
- `--include=dev` ensures devDependencies are installed
- This prevents the pruning issue

---

### Option 2: Use NPM_CONFIG Environment Variable

Alternative approach - prevent pruning altogether:

1. Go to **Environment Variables**
2. Add new variable:
   ```
   NPM_CONFIG_PRODUCTION=false
   ```
3. Keep build command as:
   ```bash
   npm install && npm run build
   ```

This tells npm to NOT prune devDependencies.

---

## Recommended Build Configuration

**Build Command:**
```bash
npm ci --include=dev && npm run build
```

**Run Command:** (keep as is)
```bash
npm exec prisma migrate deploy && npm run start:prod
```

---

## After Updating

1. Save the changes
2. DigitalOcean will automatically trigger a rebuild
3. Monitor the build logs again
4. Look for:
   - ✅ `npm ci --include=dev` success
   - ✅ `tsc -p tsconfig.build.json` success
   - ✅ Build succeeded
   - ✅ Prisma migrations running
   - ✅ Server starting

---

**Go to your app settings and update the Build Command now!**
