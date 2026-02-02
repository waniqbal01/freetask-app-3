# How to Get Deployment Logs

## Current Situation
- Deployment status: **Failed during deploy phase**
- Runtime logs: Not available (app didn't start)
- Need to check: **BUILD LOGS**

---

## Steps to View Build Logs

1. **Click**: The blue **"Go to Build Logs"** button you see in the error banner
   
   OR

2. **Navigate**: 
   - In your DigitalOcean app dashboard
   - Click **"Activity"** tab (or "Deployments")
   - Find the failed deployment
   - Click on it to view logs

---

## What to Look For

The build logs will show the entire deployment process:

1. **Git Clone** - Repository checkout
2. **Buildpack Detection** - Node.js detection
3. **npm install** - Dependencies installation
4. **npm run build** - TypeScript compilation
5. **Custom Build Command** - Our build command execution
6. **Deploy Phase** - This is where it's currently failing ❌

Look for error messages in the deploy phase section, especially:
- Prisma migration errors
- Missing environment variables
- Runtime errors
- Port binding issues

---

## Screenshot Instructions

After clicking "Go to Build Logs":

1. Scroll to the **bottom** of the logs (where the error is)
2. Scroll up a bit to get context (last 50-100 lines)
3. Take screenshot OR copy the text
4. Share with me

Focus on the section after:
```
Running custom build command: npm ci --include=dev && npm run build
```

And the deploy phase section.

---

**Click "Go to Build Logs" now and share the logs!**
