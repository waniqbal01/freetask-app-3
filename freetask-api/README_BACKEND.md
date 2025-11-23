# Freetask API

## Prerequisites
- Node.js 18+
- PostgreSQL database

## Setup
1. Copy `.env.example` to `.env`.
2. Edit `.env` and set:
   - `DATABASE_URL` to your Postgres connection string.
   - `JWT_SECRET` to a long random string (min 32 chars).
   - `ALLOWED_ORIGINS` with the frontend origins (comma-separated).
   - `UPLOAD_DIR` and `MAX_UPLOAD_MB` if you need custom upload paths/limits.
3. Install dependencies:
```bash
npm install
```
4. Generate the Prisma client:
```bash
npx prisma generate
```
5. Apply migrations:
```bash
npx prisma migrate dev
```
6. Seed demo data:
```bash
npm run seed
```
7. Start development server:
```bash
npm run start:dev
```

Swagger is available at `http://localhost:4000/api` when running.
Ensure the `./uploads` folder is persisted or mounted in deployments so uploaded files remain available.

## Platform base URLs & CORS

- **Android emulator:** `http://10.0.2.2:4000`
- **iOS simulator:** `http://localhost:4000`
- **Web/Desktop:** `http://localhost:4000`

Ensure these origins (or your chosen ones) appear in `ALLOWED_ORIGINS` inside `.env`.

### Troubleshooting
- Ensure `DATABASE_URL` points to a running Postgres instance.
- Set `JWT_SECRET` to a non-empty value; the app will refuse to start otherwise.
