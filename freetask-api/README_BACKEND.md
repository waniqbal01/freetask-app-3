# Freetask API

## Prerequisites
- Node.js 18+
- PostgreSQL database

## Setup
1. Copy `.env.example` to `.env` and fill the values.
2. Install dependencies:
```bash
npm install
```
3. Run migrations:
```bash
npx prisma migrate deploy
```
4. Seed demo data:
```bash
npm run seed
```
5. Start development server:
```bash
npm run start:dev
```

Swagger is available at `http://localhost:4000/api` when running.

## Platform base URLs & CORS

- **Android emulator:** `http://10.0.2.2:4000`
- **iOS simulator:** `http://localhost:4000`
- **Web/Desktop:** `http://localhost:4000`

Ensure these origins (or your chosen ones) appear in `ALLOWED_ORIGINS` inside `.env`.

### Troubleshooting
- Ensure `DATABASE_URL` points to a running Postgres instance.
- Set `JWT_SECRET` to a non-empty value; the app will refuse to start otherwise.
