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

- Set `ALLOWED_ORIGINS` in production; the API fails fast if it is empty.
- When `NODE_ENV=production`, `ALLOWED_ORIGINS` **must** be set or the API will exit at startup.
- Set `PUBLIC_BASE_URL` to your API origin; upload responses return relative `/uploads/<file>` paths and require JWT to fetch.
- Set `TRUST_PROXY=true` when running behind ingress/reverse-proxy so forwarded headers are trusted for URL validation.

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

- `SEED_FORCE=true npm run seed` — paksa tambah rekod walaupun DB ada data. Selamat untuk menambah pengguna/perkhidmatan demo tanpa memadam data sedia ada.
- `SEED_RESET=true npm run seed` — padam data demo dahulu sebelum masukkan semula (destruktif, untuk dev sahaja). Guna ini apabila mahu set semula akaun/escrow sebelum pengujian baharu.

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
requests with Authorization.

Demo logins from the seed (role → email / password):

- Admin: `admin@example.com` / `Password123!`
- Client: `client@example.com` / `Password123!`
- Freelancer: `freelancer@example.com` / `Password123!`
- Extras for multi-user flows: `client1@example.com`, `client2@example.com`, `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!` for all)
> Reseeding dengan `SEED_RESET=true` akan memulihkan set akaun demo di atas sebelum ujian dijalankan.

## Flutter client quickstart

The Flutter application lives in the [`freetask_app`](freetask_app/) directory. To fetch
dependencies and run the project locally, make sure you have the Flutter SDK installed,
then execute:

```bash
cd freetask_app
flutter pub get
```

The backend runs on port **4000** by default. Flutter will pick sensible defaults
per platform, but you can override them at runtime via **Tukar API Server** in the
app (or by using `--dart-define=API_BASE_URL` at build time):

* **Android emulator** (default: `http://10.0.2.2:4000`)

  ```bash
  flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
  ```

* **iOS simulator / macOS dev** (default: `http://localhost:4000` or `http://127.0.0.1:4000`)

  ```bash
  flutter run -d ios --dart-define=API_BASE_URL=http://localhost:4000
  ```

* **Web / Chrome** (default: `http://localhost:4000`)

  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
  ```

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

## Manual E2E test guide

Auth

1. `POST /auth/register` with role `ADMIN` should return 400; `CLIENT`/`FREELANCER` should succeed.
2. Missing `JWT_SECRET` in `.env` should prevent the API from starting.

Jobs

1. Create job from Flutter (client) with title/description/amount at or above the minimums (10 characters, RM1.00) – succeeds; shorter description or lower amount should be blocked by UI or return 400 with clear message.
2. As freelancer, accept → start → complete; client cannot call complete.
3. Invalid transitions (e.g. complete from `PENDING`) return conflict messages.

Escrow / Payments

1. Admin can view any job detail and hit `POST /escrow/:jobId/hold` → status `HELD`.
2. From `HELD`, admin can `release` or `refund` and status persists after restart.
3. Non-admin participants calling escrow actions receive `403/404`; GET still works for participants when enabled.

Chat

1. Open a job chat from list: `/chats/:jobId/messages` should load messages.
2. Sending a message appends to the same thread without 404s.

Uploads

1. Upload valid JPG/PNG/PDF/DOC/DOCX under 5MB – URL returned.
2. Upload unsupported type or >5MB – API responds 400 and file is rejected.

See [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md) for deployment hardening (env
requirements, proxy headers, uploads volume, and seed usage guidance).

Env & onboarding

1. Backend: `cp .env.example .env && npm install && npx prisma migrate dev && npm run seed && npm run start:dev`.
2. Flutter: `flutter pub get` then `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000` (emulator) or your host.
