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
