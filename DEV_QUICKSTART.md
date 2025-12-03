# 🚀 Freetask Developer Quickstart (5 Minutes)

Get the Freetask MVP running locally in 5 minutes with this step-by-step guide.

## Prerequisites

- **Node.js** (v18+) → [Download here](https://nodejs.org/)
- **Flutter SDK** (v3.0+) → [Install guide](https://docs.flutter.dev/get-started/install)
- **PostgreSQL** (v14+) → [Download here](https://www.postgresql.org/download/)
- **Git** for cloning the repository

## Quick Setup Commands

### 1. Clone and Setup Backend (2 minutes)

```bash
# Clone the repository
git clone <repository-url>
cd freetask-app-3

# Navigate to API directory
cd freetask-api

# Copy environment configuration
cp .env.example .env

# Install dependencies
npm install

# Setup database (Prisma migrations)
npx prisma migrate dev

# Seed demo data
npm run seed
```

### 2. Setup Flutter App (1 minute)

```bash
# Navigate to Flutter app directory
cd ../freetask_app

# Install dependencies
flutter pub get
```

### 3. Run Both Services (30 seconds)

**Terminal 1 - API Server:**
```bash
cd freetask-api
npm run start:dev
```

**Terminal 2 - Flutter App:**
```bash
cd freetask_app
flutter run
```

## 🔑 Demo Credentials

After seeding, use these credentials to test different roles:

| Role       | Email                    | Password      |
|------------|--------------------------|---------------|
| **Admin**  | `admin@example.com`      | `Password123!` |
| Client     | `client@example.com`     | `Password123!` |
| Freelancer | `freelancer@example.com` | `Password123!` |

**Additional test accounts:** `client1@example.com`, `client2@example.com`, `freelancer1@example.com`, `freelancer2@example.com` (all use `Password123!`)

## Platform-Specific API URLs

The app automatically detects the correct API URL for each platform:

- **Android Emulator:** `http://10.0.2.2:4000`
- **iOS Simulator:** `http://localhost:4000`
- **Web/Chrome:** `http://localhost:4000`
- **Physical Device:** Use your computer's LAN IP (e.g., `http://192.168.1.100:4000`)

**Change API URL at runtime:**
1. Click the settings icon on the login screen
2. Select "Tukar API Server"
3. Enter your API URL or use quick-select options

## 🛠️ Common Troubleshooting

### Backend Won't Start

**Issue:** Database connection error
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Solution:**
1. Ensure PostgreSQL is running
2. Check `DATABASE_URL` in `.env` matches your Postgres credentials:
   ```env
   DATABASE_URL=postgresql://USER:PASSWORD@localhost:5432/freetask?schema=public
   ```
3. Create the database if it doesn't exist:
   ```bash
   psql -U postgres
   CREATE DATABASE freetask;
   \q
   ```

### Flutter Web Login Error

**Issue:** "XMLHttpRequest onError callback was called"

**Solution:**
1. Verify API is running: Open `http://localhost:4000/health` in browser (should return `{"status":"ok"}`)
2. For development, ensure `ALLOWED_ORIGINS` in `.env` is empty or includes Flutter web port:
   ```env
   ALLOWED_ORIGINS=
   ```
3. Restart the API server after changing `.env`

### API URL Not Reachable on Physical Device

**Issue:** App can't connect to `http://localhost:4000`

**Solution:**
1. Find your computer's LAN IP:
   - **Windows:** `ipconfig` (look for IPv4 Address)
   - **Mac/Linux:** `ifconfig` or `ip addr` (look for 192.168.x.x)
2. Use that IP in the app's API settings (e.g., `http://192.168.1.100:4000`)
3. Add your LAN IP to `.env`:
   ```env
   PUBLIC_BASE_URL=http://192.168.1.100:4000
   ALLOWED_ORIGINS=http://192.168.1.100:4000
   ```

### Seed Data Issues

**Reseed the database:**
```bash
cd freetask-api
SEED_RESET=true npm run seed  # ⚠️ Deletes all data and reseeds
```

⚠️ **WARNING:** `SEED_RESET=true` wipes ALL data. Only use in development!

## Next Steps

- **Explore the API:** `http://localhost:4000/api` (Swagger documentation)
- **Admin Dashboard:** Login as `admin@example.com` to test escrow actions
- **Create a Service:** Login as `freelancer@example.com` → Create Service
- **Book a Job:** Login as `client@example.com` → Browse Services → Book
- **Test Job Lifecycle:** Accept → Start → Complete → Leave Review

## Development Workflow

### R unseeding database (safe)
```bash
cd freetask-api
npm run seed  # Safe upsert of demo data
```

### Run with specific API URL
```bash
cd freetask_app
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:4000
```

### Run tests
```bash
# Backend tests
cd freetask-api
npm test

# Flutter tests
cd freetask_app
flutter test
```

## Environment Variables Reference

**Minimal `.env` for local development:**

```env
DATABASE_URL=postgresql://USER:PASSWORD@localhost:5432/freetask?schema=public
JWT_SECRET=CHANGE_ME_SUPER_SECRET_AT_LEAST_32_CHARACTERS_LONG
JWT_REFRESH_EXPIRES_IN=7d
PUBLIC_BASE_URL=http://localhost:4000
ALLOWED_ORIGINS=
```

> 💡 **Tip:** Leave `ALLOWED_ORIGINS` empty for development to enable wildcard CORS. For production, always specify exact origins!

## Need Help?

- **API Documentation:** Check `README.md` in `freetask-api/`
- **Flutter Docs:** See `freetask_app/README.md`
- **Architecture:** Review `DEPLOYMENT.md` and `MONITORING.md`

---

**Time to first render:** ~5 minutes ⚡  
**Seeded demo accounts:** 7 users across all roles ✅  
**Next:** Start exploring the job lifecycle! 🚀
