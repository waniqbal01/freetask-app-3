# freetask-app-3

This repository contains the Flutter project scaffold for the **FreeTask App** and the
NestJS API powering it.

## 🚀 Quickstart (5 langkah)

1. `cp freetask-api/.env.example freetask-api/.env`
2. `cd freetask-api && npm install`
3. `npx prisma migrate dev`
4. `npm run seed` (guna `SEED_FORCE=true` atau `SEED_RESET=true npm run seed` untuk reseed pantas)
5. Jalankan API `npm run start:dev` **dan** Flutter app `cd ../freetask_app && flutter pub get && flutter run`

## ⚠️ Production Requirements (mandatory)

- **JWT Configuration (Required):**
  - Set `JWT_SECRET` to a strong, random secret (minimum 32 characters recommended)
  - Set `JWT_REFRESH_EXPIRES_IN` (e.g., `7d`) - **API will fail to start without this in production**
- **CORS Configuration (Required):**
  - Set `ALLOWED_ORIGINS` in production; the API fails fast if it is empty
  - When `NODE_ENV=production`, `ALLOWED_ORIGINS` **must** be set or the API will exit at startup
  - Never use wildcard `*` in production - explicitly list all client origins
- **URL Configuration:**
  - Set `PUBLIC_BASE_URL` to your API origin; upload responses return relative `/uploads/<file>` paths and require JWT to fetch
  - Set `TRUST_PROXY=true` when running behind ingress/reverse-proxy so forwarded headers are trusted for URL validation
- **Upload Security:**
  - All `/uploads/:filename` requests are protected by JWT (downloads included). Clients must send the `Authorization: Bearer <token>` header or they will receive `401/403` responses.

## Backend quickstart (NestJS + Prisma/Postgres)

```bash
cd freetask-api
cp .env.example .env
npm install
npx prisma migrate dev
# Seed sample users/services (safe by default)
npm run seed
npm run start:dev
```

Reseed flags:

- `SEED_FORCE=true npm run seed` — **⚠️ WARNING:** Force-adds demo users via `upsert`.  
  If demo emails (`client@example.com`, etc.) match real production users, their passwords/roles will be overwritten.  
  **NEVER use in production**. Safe for dev if demo emails are unique.
- ⚠️ **WARNING: `SEED_RESET=true` WIPES ALL DEMO DATA PERMANENTLY.** Use only in dev environment. This command deletes existing data before reseeding.

**Do not skip envs in production** – set `ALLOWED_ORIGINS`/`PUBLIC_BASE_URL` so the
API can emit correct URLs and allow only intended origins. The server now fails fast
when `ALLOWED_ORIGINS` is empty in production.

Copy/paste starter envs:

- **Local dev (web + emulator)**

  ```env
  DATABASE_URL=postgresql://USER:PASSWORD@localhost:5432/freetask?schema=public
  JWT_SECRET=CHANGE_ME_SUPER_SECRET
  PUBLIC_BASE_URL=http://localhost:4000
  ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://10.0.2.2:4000,http://localhost:4000,http://127.0.0.1:4000
  ```

- **Staging (LAN/IP testing)**

  ```env
  PUBLIC_BASE_URL=http://192.168.0.10:4000
  ALLOWED_ORIGINS=http://192.168.0.10:4000,http://10.0.2.2:4000
  ```

- **Production (web)**

  ```env
  PUBLIC_BASE_URL=https://api.freetask.my
  ALLOWED_ORIGINS=https://app.freetask.my,https://admin.freetask.my
  ```

Persist uploads between restarts by mounting/volume-binding the `./uploads` folder
when running in Docker or on a host machine. `/uploads/**` URLs require JWT headers;
upload responses return relative paths (e.g. `/uploads/<file>`) that the Flutter app
requests with Authorization. **Note for web:** `Image.network` on Flutter web requires
`httpHeaders` parameter with JWT Bearer token to load uploaded images.

> **💡 Tip**: Uploads are stored in `./uploads` (gitignored to prevent accidental commits).

**🔑 Demo Logins (Seeded Credentials)**

After running `npm run seed`, use these credentials to test different roles:

| Role       | Email                      | Password      |
|------------|----------------------------|---------------|
| **Admin**  | `admin@example.com`        | `Password123!` |
| Client     | `client@example.com`       | `Password123!` |
| Freelancer | `freelancer@example.com`   | `Password123!` |

Additional test accounts: `client1@example.com`, `client2@example.com`, `freelancer1@example.com`, `freelancer2@example.com` (all use `Password123!`).

> **💡 Tip:** Use `admin@example.com` to test escrow hold/release/refund actions in the admin dashboard. Jobs with HELD/DISPUTED escrow status are seeded for testing.

> Reseeding dengan `SEED_RESET=true` akan memulihkan set akaun demo di atas sebelum ujian dijalankan.

## Flutter client quickstart

> 🚨 **iOS Physical Device Users:** The default `http://localhost:4000` only works for iOS simulator. For physical iOS devices, you **must** override the API URL in the app via **Tukar API Server** (Settings menu) or use `--dart-define=API_BASE_URL=http://YOUR_LAN_IP:4000` (e.g., `http://192.168.1.100:4000`). See the API settings screen for runtime configuration.

The Flutter application lives in the [`freetask_app`](freetask_app/) directory. To fetch
dependencies and run the project locally, make sure you have the Flutter SDK installed,
then execute:

```bash
cd freetask_app
flutter pub get
```

## Running Tests

### Backend Tests

```bash
cd freetask-api
npm test              # Run all unit tests
npm run test:e2e      # Run integration tests (if configured)
npm run test:cov      # Generate coverage report
```

### Flutter Tests

```bash
cd freetask_app
flutter test                    # Run all tests
flutter test --coverage         # With coverage report
flutter test integration_test/  # E2E tests (if configured)
```

The backend runs on port **4000** by default. Flutter will pick sensible defaults
per platform, but you can override them at runtime via **Tukar API Server** in the
app (or by using `--dart-define=API_BASE_URL` at build time):

* **Android emulator** (default: `http://10.0.2.2:4000`)

  ```bash
  flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
  ```

* **Web / Chrome** (default: `http://localhost:4000`)

  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
  ```

> **Web Testing Note**: Flutter web dev server uses a random port (e.g. `http://localhost:53678`).  
> For local testing, you can either:
> - Set `ALLOWED_ORIGINS=http://localhost:*` in `.env` (development only)
> - OR add the exact port after running flutter (e.g., `ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:53678`)
>
> 🚨 **NEVER use wildcard `*` patterns in ALLOWED_ORIGINS for production.** Explicitly list all client origins (web, mobile). Wildcard patterns expose your API to CORS-based attacks in production environments.

### 🐛 Troubleshooting Flutter Web Login

**Error: "The XMLHttpRequest onError callback was called..."**

This typically indicates a CORS issue with Flutter Web's random port:

1. **Check if backend is running:** Open browser to `http://localhost:4000/health` → Should return `{"status":"ok"}`

2. **CORS Solution (Development):**
   - **Option A (Recommended):** Leave `ALLOWED_ORIGINS` empty in `freetask-api/.env`
     ```env
     ALLOWED_ORIGINS=
     ```
     This enables wildcard `*` fallback in development mode.
   
   - **Option B:** Add the exact Flutter Web port to `ALLOWED_ORIGINS`:
     ```bash
     # After running `flutter run -d chrome`, note the port (e.g., http://localhost:63599)
     # Then add to .env:
     ALLOWED_ORIGINS=http://localhost:63599,http://localhost:4000
     ```
     ⚠️ Remember to restart backend after changing `.env`

3. **Verify API URL in Flutter:**
   - Click "Tukar API Server" on login screen
   - Ensure it's set to `http://localhost:4000`

4. **Test health endpoint from Flutter Web:**
   - Open browser console (F12) → Network tab
   - Login should show request to `http://localhost:4000/auth/login`
   - If you see CORS error, double-check step 2

> **💡 Production Note:** Never use empty `ALLOWED_ORIGINS` or wildcard in production. Always specify exact origins.

**iOS** (if simulator is running):

  ```bash
  flutter run -d ios --dart-define=API_BASE_URL=http://localhost:4000
  ```

> ✅ **iOS Configuration Confirmed**: The default `http://localhost:4000` works correctly for iOS simulator. Physical iOS devices require your LAN IP (e.g., `http://192.168.x.x:4000`).

For web/desktop testing, ensure your browser origin (e.g. `http://localhost:3000` or
`http://localhost:5173`) appears in `ALLOWED_ORIGINS` when running the API in production.
Use your LAN IP (e.g. `http://192.168.x.x:4000`) for physical devices and include it
in both `PUBLIC_BASE_URL` and `ALLOWED_ORIGINS`. Jika ujian dijalankan oleh QA dari mesin berbeza, semak semula senarai `ALLOWED_ORIGINS` supaya host frontend mereka tidak disekat oleh CORS.

## Readiness checklist (RED → GREEN)

- [x] Public registration locked to `CLIENT`/`FREELANCER` roles only.
- [x] JWT secret + expiry enforced at startup (fails fast when missing).
- [x] Chat routes aligned to `/chats/:jobId/messages` on API + Flutter.
- [x] API base URL configurable per platform via `--dart-define=API_BASE_URL`.
- [x] CORS honours explicit `ALLOWED_ORIGINS` (required in production).
- [x] Job creation payload requires amount/description with safe Decimal casting.
- [x] Job creation enforces minimum description length (10 characters) and amount (RM1.00) across API + Flutter constants.
- [x] Uploads constrained by size/MIME with sanitized filenames.
- [x] Global rate limiter enabled (30 req/min default) beyond auth.
- [x] Login screen documents seed credentials for quick QA.

## API Conventions

### Avatar Upload Field

> **⚠️ API Change Notice**: The `avatar` field in registration and user update payloads is **deprecated**.  
> Use `avatarUrl` instead. The legacy `avatar` field is kept for backward compatibility with older clients and will be removed in API v2.

**Example:**
```json
// ✅ Preferred
POST /auth/register
{
  "email": "user@example.com",
  "password": "Password123!",
  "name": "John Doe",
  "role": "CLIENT",
  "avatarUrl": "https://example.com/avatar.jpg"
}

// ⚠️ Legacy (still works, but deprecated)
{
  "avatar": "https://example.com/avatar.jpg"
}
```

## Manual E2E test guide

Auth

1. `POST /auth/register` with role `ADMIN` should return 400; `CLIENT`/`FREELANCER` should succeed.
2. Missing `JWT_SECRET` in `.env` should prevent the API from starting.
3. **Token Refresh:** GoRouter guards leverage refresh interceptors to automatically renew expired access tokens. Expected UX: seamless re-authentication without logout on token expiry.

Jobs

1. Create job from Flutter (client) with title/description/amount at or above the minimums (10 characters, RM1.00) – succeeds; shorter description or lower amount should be blocked by UI or return 400 with clear message.
2. As freelancer, accept → start → complete; client cannot call complete.
3. Invalid transitions (e.g. complete from `PENDING`) return conflict messages.

Escrow / Payments

**Admin escrow control paths:**
- `POST /escrow/:jobId/hold` — Hold funds (requires ADMIN role)
- `POST /escrow/:jobId/release` — Release funds to freelancer (requires ADMIN, job must be COMPLETED/DISPUTED)
- `POST /escrow/:jobId/refund` — Refund funds to client (requires ADMIN, job must be CANCELLED/REJECTED/DISPUTED)
- `GET /escrow/:jobId` — View escrow status (job participants + ADMIN)

**Test scenarios:**
1. Admin can view any job detail and hit `POST /escrow/:jobId/hold` → status `HELD`.
2. From `HELD`, admin can `release` or `refund` and status persists after restart.
3. Non-admin participants calling escrow actions receive `403/404`; GET still works for participants when enabled.
4. Seed creates jobs with HELD/DISPUTED escrow for immediate admin testing (see seeded credentials above).

**Escrow Admin Manual Test Steps** (Step-by-Step QA Guide):
1. Login as `admin@example.com` with password `Password123!`
2. Navigate to `/admin` dashboard to view all jobs
3. Find a job with `HELD` escrow status (e.g., "Brand identity package" - seeded job)
4. Click "Release Funds" button
5. Verify job escrow status changes to `RELEASED` and persists after page refresh
6. Find a job with `DISPUTED` escrow status (seeded in demo data)
7. Click "Refund" button
8. Verify job escrow status changes to `REFUNDED` and persists after restart
9. Logout and login as `client@example.com` to verify non-admin users cannot see escrow admin actions

Chat

1. Open a job chat from list: `/chats/:jobId/messages` should load messages.
2. Sending a message appends to the same thread without 404s.

> **ℹ️ Chat Design**: MVP uses REST polling (GET `/chats/:jobId/messages`). Real-time WebSocket support planned for Phase 2.

Uploads

1. Upload valid JPG/PNG/PDF/DOC/DOCX under 5MB – URL returned.
2. Upload unsupported type or >5MB – API responds 400 and file is rejected.
3. **Web images:** Flutter web `Image.network` requires `httpHeaders` with JWT Bearer token.

Health Check

- `GET /health` returns `{"status":"ok"}` when DB is reachable (no detailed probe info exposed).
- **Production:** Consider adding authentication or rate limiting to prevent abuse.

See [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md) for deployment hardening (env
requirements, proxy headers, uploads volume, and seed usage guidance).

Env & onboarding

1. Backend: `cp .env.example .env && npm install && npx prisma migrate dev && npm run seed && npm run start:dev`.
2. Flutter: `flutter pub get` then `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000` (emulator) or your host.
