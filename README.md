# Freetask
A services marketplace connecting **clients** with **freelancers**. This monorepo contains the NestJS backend and Flutter app that power authentication, service listings, job workflows, chat, and more.

## Tech Stack
- **Backend**: NestJS, Prisma, PostgreSQL, Socket.IO
- **Mobile/Web**: Flutter, Riverpod, Dio

## Repository Layout
- `freetask-api/` – NestJS API and Prisma schema
- `freetask_app/` – Flutter application (mobile & web)

## Current Features
- Authentication (JWT) and profile management
- Service listings and categories
- Job lifecycle (create, accept/reject, start, complete, dispute)
- In-app chat per job
- File uploads for avatars/attachments
- Basic payments & reviews (UI scaffolding; backend endpoints can be extended)
- Notifications feed
- Admin health/stats entry point

## Getting Started
### Prerequisites
- Node.js 20+ and npm
- Flutter 3.22+ and Dart SDK
- PostgreSQL 14+
- Android/iOS simulator or Chrome for running the app

### Backend (NestJS)
```bash
cd freetask-api
npm install
cp .env.example .env
npm run db:setup         # migrate + seed demo data
npm run start:dev
```
Swagger UI: http://localhost:4000/api/docs
Health check: http://localhost:4000/health (returns API + DB status)

### Flutter App
```bash
cd freetask_app
flutter pub get
# Android emulator
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
# Web / Chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

## Environment Variables (backend)
- `DATABASE_URL` – PostgreSQL connection string
- `JWT_SECRET` – Secret used to sign JWTs
- `PORT` – API port (defaults to 4000)
- `ALLOWED_ORIGINS` – Comma-separated CORS whitelist
- `JWT_EXPIRES_IN` – Token lifetime (e.g., `7d`)

## Useful Scripts
**Backend**
- `npm run start:dev` – Start API in watch mode
- `npm run prisma:migrate` – Run Prisma migrations (dev)
- `npm run prisma:seed` – Seed sample data
- `npm run db:setup` – Migrate + seed demo accounts/services/jobs
- `npm test` – Execute Jest test suite

**Flutter**
- `flutter run --dart-define=API_BASE_URL=...` – Run app against an API instance
- `flutter test` – Run widget/provider tests
- `dart format .` / `flutter analyze` – Format and analyze code

## MVP Guidance for Testers
- Demo accounts: admin@demo.com / Admin123!, client@demo.com / Client123!, freelancer@demo.com / Freelancer123!
- Payment is **mock/coming soon** only; no real gateway integration.
- Reviews & Reports are basic/optional for MVP and may not be surfaced fully in the app UI.
- Chat uses REST as the primary path; realtime socket updates are best-effort.
- CORS: defaults cover localhost/10.0.2.2/5173; add extra origins via `ALLOWED_ORIGINS` in `.env` (comma-separated).

## Dev Notes – Phase 1
- Backend: copy `.env.example` to `.env`, update credentials, then `npm run db:setup` before `npm run start:dev`.
- Flutter: run with `--dart-define=API_BASE_URL=http://10.0.2.2:4000` on Android emulators or `http://localhost:4000` on web/desktop.
- CORS: `ALLOWED_ORIGINS` in the backend `.env` accepts comma-separated origins; defaults already include common local hosts and `10.0.2.2` for Android.

## Testing Setup
- See [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) for one-page setup + demo accounts.
- Contract references live in [docs/API_CONTRACT_MATRIX.md](docs/API_CONTRACT_MATRIX.md).

## MVP Test Instructions
Follow these quick steps to verify the end-to-end flow (login → role home → services → job → chat → status) across web and mobile:

1) **Backend (NestJS + Prisma)**
   - `cd freetask-api && npm install`
   - `cp .env.example .env` then update `DATABASE_URL` if needed.
   - `npm run db:setup` (runs migrations + seeds demo data).
   - `npm run start:dev` and keep it running at http://localhost:4000.

2) **Flutter App (web or emulator)**
   - `cd freetask_app && flutter pub get`
   - Web/Chrome: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000`
   - Android emulator: `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000`

3) **Demo credentials**
   - Admin: `admin@demo.com / Admin123!`
   - Client: `client@demo.com / Client123!`
   - Freelancer: `freelancer@demo.com / Freelancer123!`

4) **Role & job flow (happy path)**
   - Client login → pilih servis → cipta job → status **PENDING**.
   - Freelancer login → terima job (**ACCEPTED**) → mula kerja (**IN_PROGRESS**).
   - Chat dalam job kekal tersedia; cuba hantar mesej ringkas.
   - Client atau freelancer boleh tandakan siap (**COMPLETED**) atau dispute (**DISPUTED**) bila perlu.

5) **CORS & env tips**
   - Default whitelist merangkumi `localhost`, `10.0.2.2`, dan port 5173 untuk Flutter web.
   - Tambah origin lain melalui `ALLOWED_ORIGINS` dalam `.env` jika test dari iOS simulator atau domain staging/production.

## Architecture & Docs
- [Backend architecture](freetask-api/docs/backend-architecture.md)
- [Flutter app architecture](freetask_app/docs/flutter-architecture.md)
- [Operations (run/test/deploy)](docs/operations.md)

Diagrams and deeper module notes live in the linked architecture docs.
