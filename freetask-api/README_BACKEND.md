# Freetask API

## ⚠️ Production Requirements (mandatory)

- `ALLOWED_ORIGINS` **must** be set in production; the server now fails fast when empty.
- `PUBLIC_BASE_URL` should point to your API origin; upload responses return relative paths and still require JWT for retrieval.
- `TRUST_PROXY=true` when running behind ingress/reverse-proxy so forwarded headers are trusted.

If `ALLOWED_ORIGINS` is empty in production the API will exit. Missing `PUBLIC_BASE_URL` in production prevents safe upload link generation.

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
3. Update `.env` with your database connection, JWT secret, and `PUBLIC_BASE_URL`
   (e.g. `http://localhost:4000` for local dev, `http://192.168.x.x:4000` for LAN
   devices, or your production domain). The default `ALLOWED_ORIGINS` covers local
   web/desktop testing. **In production, `ALLOWED_ORIGINS` is required – the server
   fails fast if it is empty.** Set `PUBLIC_BASE_URL` to your API origin (uploads
   still return relative URLs and need Authorization headers to download).
4. Apply Prisma migrations:
```bash
npx prisma migrate dev
```
5. Seed demo data (safe by default – no truncation unless `SEED_RESET=true`):
```bash
npm run seed
```
   - If the database already has data, the seed will stop unless you set `SEED_FORCE=true`.
   - To wipe demo tables first, run `SEED_RESET=true npm run seed` (destructive: deletes users, services, jobs, chats, reviews).
6. Start development server:
```bash
npm run start:dev
```

Seed credentials (role → email / password):

- Admin: `admin@example.com` / `Password123!`
- Client: `client@example.com` / `Password123!`
- Freelancer: `freelancer@example.com` / `Password123!`
- Extra demo accounts: `client1@example.com`, `client2@example.com`, `freelancer1@example.com`, `freelancer2@example.com` (all `Password123!`)

## Production env checklist

- `PUBLIC_BASE_URL` – set to your API origin; used to build upload URLs (responses
  return relative `/uploads/<file>` paths; downloads require Authorization headers).
- `ALLOWED_ORIGINS` – explicit list of allowed frontends (e.g. admin + app domains).
- `NODE_ENV` – when set to `production`, `ALLOWED_ORIGINS` must be populated or the API will exit at startup.
- `TRUST_PROXY=true` – enable when running behind ingress/reverse-proxy so forwarded
  headers are trusted.

Environment summary:

- `DATABASE_URL` – Postgres connection string
- `JWT_SECRET` – secret for signing tokens
- `JWT_ACCESS_EXPIRES_IN` – access token lifetime (default `30m`)
- `JWT_REFRESH_EXPIRES_IN` – refresh token lifetime (default `14d`)
- `ALLOWED_ORIGINS` – comma-separated list of allowed CORS origins (dev falls back to
  common localhost/lan URLs if empty, including `http://192.168.*.*` and emulator
  hosts such as `http://10.0.2.2:*`). **Required in production – the app will exit
  if empty.**
- `PORT` – defaults to `4000`
- `UPLOAD_DIR` – folder where files are stored (default `uploads` relative to project root)
- `PUBLIC_BASE_URL` – required in production to build absolute upload URLs (set to
  your API origin, e.g. `https://api.example.com`)
- `PUBLIC_BASE_URL_STRICT` – keep `true` to enforce host matching, set to `false` when
  running behind reverse proxies/ingress that rewrite hosts
- `TRUST_PROXY` – set to `true` to trust `X-Forwarded-*` headers for upload URL
  generation when behind a proxy
- `SEED_FORCE` – set to `true` to allow seeding when data already exists (dev auto-seeds an empty DB once)
- `SEED_RESET` – defaults to `false` (non-destructive). Set to `true` only when you intentionally want to wipe data.

Demo credentials from the seed script:

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` (password `Password123!`)
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!`)

Swagger docs are served at `/api` (e.g. `http://localhost:4000/api` locally or
`https://<your-domain>/api` in production). Ensure the `./uploads` folder is
persisted or mounted in deployments so uploaded files remain available.

See [`../PRODUCTION_CHECKLIST.md`](../PRODUCTION_CHECKLIST.md) before deploying
to production (required envs, proxy headers, uploads volume, and seed guidance).

## Platform base URLs & CORS

- **Android emulator:** `http://10.0.2.2:4000`
- **iOS simulator:** `http://localhost:4000` or `http://127.0.0.1:4000`
- **Web/Desktop:** `http://localhost:4000` (web clients often originate from
  `http://localhost:3000` or `http://localhost:5173`)

Ensure these origins (or your chosen ones) appear in `ALLOWED_ORIGINS` inside `.env`.
If `ALLOWED_ORIGINS` is empty during local development, the server will auto-allow
`http://localhost:4000`, `http://127.0.0.1:4000`, `http://localhost:3000`,
`http://localhost:5173`, and `http://10.0.2.2:4000` for quick testing. **In
production the server will exit when `ALLOWED_ORIGINS` is empty** to avoid
unintentional permissive CORS.

When `PUBLIC_BASE_URL` is set, the upload URL host is enforced. Disable enforcement via
`PUBLIC_BASE_URL_STRICT=false` or set `TRUST_PROXY=true` to respect `X-Forwarded-Host`
and `X-Forwarded-Proto` headers if running behind ingress/reverse proxy. Persist the
`./uploads` directory via a Docker volume or host bind mount to avoid losing files
between restarts.

### Env presets

- **Local dev (web + emulator)**

  ```env
  PUBLIC_BASE_URL=http://localhost:4000
  ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://10.0.2.2:4000,http://localhost:4000,http://127.0.0.1:4000
  ```

- **Staging / LAN**

  ```env
  PUBLIC_BASE_URL=http://192.168.0.10:4000
  ALLOWED_ORIGINS=http://192.168.0.10:4000,http://10.0.2.2:4000
  ```

- **Production (web)**

  ```env
  PUBLIC_BASE_URL=https://api.freetask.my
  ALLOWED_ORIGINS=https://app.freetask.my,https://admin.freetask.my
  ```

### Troubleshooting
- Ensure `DATABASE_URL` points to a running Postgres instance.
- Set `JWT_SECRET` to a non-empty value; the app will refuse to start otherwise.
- In production, set `ALLOWED_ORIGINS` or `PUBLIC_BASE_URL` to avoid CORS being blocked
  for all origins.
- Uploads larger than 5MB or outside the allowed MIME list (jpeg/png/gif/pdf/doc/docx) are rejected.

## API contract updates

- `GET /jobs/:id` accepts `ADMIN` tokens to view any job. Non-admin users must still be the client
  or freelancer or will receive `404/403`.
- Escrow endpoints:
  - `GET /escrow/:jobId` (admin, client, or freelancer) returns `{ id, jobId, status, amount, createdAt, updatedAt }`.
  - `POST /escrow/:jobId/hold` → status transitions `PENDING -> HELD` (admin only).
  - `POST /escrow/:jobId/release` or `POST /escrow/:jobId/refund` require current status `HELD` (admin only);
    invalid transitions return `409` with a clear message.
- Uploads are fetched via authenticated `GET /uploads/:filename` (JWT required). Static
  directory serving is disabled; only files within the configured `UPLOAD_DIR` that pass
  the allowlist (jpeg/png/gif/pdf/doc/docx, max 5MB) can be retrieved. Upload responses
  return the storage key plus a relative path (e.g. `/uploads/<file>`), never a public
  absolute URL.

Seeding tips:
- If the database already has data, rerun with `SEED_FORCE=true`. Keep `SEED_RESET=false`
  to preserve existing rows while adding/updating seed records.
- Only set `SEED_RESET=true` for local/dev destructive reseeds (wipes reviews, chats,
  jobs, services, users before recreating).
