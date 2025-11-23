# Freetask API

## Prerequisites
- Node.js 18+
- PostgreSQL database

## Setup
1. Copy `.env.example` to `.env`.
```bash
cp .env.example .env
```
2. Install dependencies:
```bash
npm install
```
3. Update `.env` with your database connection and JWT secret if needed.
4. Apply Prisma migrations:
```bash
npx prisma migrate dev
```
5. Seed demo data:
```bash
npm run seed
```
6. Start development server:
```bash
npm run start:dev
```

Environment summary:

- `DATABASE_URL` – Postgres connection string
- `JWT_SECRET` – secret for signing tokens
- `JWT_EXPIRES_IN` – expiry duration (e.g. `7d`)
- `ALLOWED_ORIGINS` – comma-separated list of allowed CORS origins
- `PORT` – defaults to `4000`

Demo credentials from the seed script:

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` (password `Password123!`)
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!`)

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
