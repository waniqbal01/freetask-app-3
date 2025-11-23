# freetask-app-3

This repository contains the Flutter project scaffold for the **FreeTask App** and the
NestJS API powering it.

## Backend quickstart (NestJS + Prisma/Postgres)

```bash
cd freetask-api
cp .env.example .env
npm install
npx prisma migrate dev
npm run seed
npm run start:dev
```

`ALLOWED_ORIGINS` in `.env` is pre-populated for localhost testing; when left empty in
development the API allows common local origins automatically. For production, always
set an explicit list.

Demo logins from the seed:

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` (password `Password123!`)
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!`)

## Flutter client quickstart

The Flutter application lives in the [`freetask_app`](freetask_app/) directory. To fetch
dependencies and run the project locally, make sure you have the Flutter SDK installed,
then execute:

```bash
cd freetask_app
flutter pub get
```

The backend runs on port **4000** by default. Flutter will pick sensible defaults
per platform, but you can override them using `API_BASE_URL`:

* **Android emulator** (default: `http://10.0.2.2:4000`)

  ```bash
  flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
  ```

* **Web / Chrome** (default: `http://localhost:4000`)

  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
  ```

For web/desktop testing, ensure your browser origin (e.g. `http://localhost:3000` or
`http://localhost:5173`) appears in `ALLOWED_ORIGINS` when running the API in production.

## Readiness checklist (RED → GREEN)

- [x] Public registration locked to `CLIENT`/`FREELANCER` roles only.
- [x] JWT secret + expiry enforced at startup (fails fast when missing).
- [x] Chat routes aligned to `/chats/:jobId/messages` on API + Flutter.
- [x] API base URL configurable per platform via `--dart-define=API_BASE_URL`.
- [x] CORS honours explicit `ALLOWED_ORIGINS` (required in production).
- [x] Job creation payload requires amount/description with safe Decimal casting.
- [x] Uploads constrained by size/MIME with sanitized filenames.
- [x] Global rate limiter enabled (30 req/min default) beyond auth.
- [x] Login screen documents seed credentials for quick QA.

## Manual E2E test guide

Auth

1. `POST /auth/register` with role `ADMIN` should return 400; `CLIENT`/`FREELANCER` should succeed.
2. Missing `JWT_SECRET` in `.env` should prevent the API from starting.

Jobs

1. Create job from Flutter (client) with title/description/amount – succeeds.
2. As freelancer, accept → start → complete; client cannot call complete.
3. Invalid transitions (e.g. complete from `PENDING`) return conflict messages.

Chat

1. Open a job chat from list: `/chats/:jobId/messages` should load messages.
2. Sending a message appends to the same thread without 404s.

Uploads

1. Upload valid JPG/PNG/PDF under 5MB – URL returned.
2. Upload unsupported type or >5MB – API responds 400.

Env & onboarding

1. Backend: `cp .env.example .env && npm install && npx prisma migrate dev && npm run seed && npm run start:dev`.
2. Flutter: `flutter pub get` then `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000` (emulator) or your host.
