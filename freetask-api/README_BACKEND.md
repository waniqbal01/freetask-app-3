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
3. Update `.env` with your database connection, JWT secret, and `PUBLIC_BASE_URL`
   (e.g. `http://localhost:4000` for local dev, `http://192.168.x.x:4000` for LAN
   devices, or your production domain). The default `ALLOWED_ORIGINS` covers local
   web/desktop testing. **Production boots will now fail fast if `ALLOWED_ORIGINS`
   and `PUBLIC_BASE_URL` are empty—set at least one.**
4. Apply Prisma migrations:
```bash
npx prisma migrate dev
```
5. Seed demo data:
```bash
SEED_FORCE=true npm run seed
```
6. Start development server:
```bash
npm run start:dev
```

Environment summary:

- `DATABASE_URL` – Postgres connection string
- `JWT_SECRET` – secret for signing tokens
- `JWT_ACCESS_EXPIRES_IN` – access token lifetime (default `30m`)
- `JWT_REFRESH_EXPIRES_IN` – refresh token lifetime (default `14d`)
- `ALLOWED_ORIGINS` – comma-separated list of allowed CORS origins (dev falls back to
  common localhost/lan URLs if empty, including `http://192.168.*.*` and emulator
  hosts such as `http://10.0.2.2:*`). **Required in production unless
  `PUBLIC_BASE_URL` is set.**
- `PORT` – defaults to `4000`
- `PUBLIC_BASE_URL` – required in production to build absolute upload URLs (set to
  your API origin, e.g. `https://api.example.com`)
- `PUBLIC_BASE_URL_STRICT` – keep `true` to enforce host matching, set to `false` when
  running behind reverse proxies/ingress that rewrite hosts
- `TRUST_PROXY` – set to `true` to trust `X-Forwarded-*` headers for upload URL
  generation when behind a proxy
- `SEED_FORCE` – set to `true` to allow seeding (dev auto-seeds an empty DB once)
- `SEED_RESET` – set to `false` to preserve data on reseed; defaults to destructive mode

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
- **iOS simulator:** `http://localhost:4000`
- **Web/Desktop:** `http://localhost:4000`

Ensure these origins (or your chosen ones) appear in `ALLOWED_ORIGINS` inside `.env`.
If `ALLOWED_ORIGINS` is empty during local development, the server will auto-allow
`http://localhost:4000`, `http://127.0.0.1:4000`, `http://localhost:3000`,
`http://localhost:5173`, and `http://10.0.2.2:4000` for quick testing. In production,
the server will still boot when `ALLOWED_ORIGINS` is empty but will block unknown
origins and warn loudly—set `ALLOWED_ORIGINS` (or `PUBLIC_BASE_URL`) to avoid this.

When `PUBLIC_BASE_URL` is set, the upload URL host is enforced. Disable enforcement via
`PUBLIC_BASE_URL_STRICT=false` or set `TRUST_PROXY=true` to respect `X-Forwarded-Host`
and `X-Forwarded-Proto` headers if running behind ingress/reverse proxy. Persist the
`./uploads` directory via a Docker volume or host bind mount to avoid losing files
between restarts.

### Env presets

- **Local dev (web + emulator)**

  ```env
  PUBLIC_BASE_URL=http://localhost:4000
  ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://10.0.2.2:3000,http://localhost:4000,http://127.0.0.1:4000
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

Seeding tips:
- If the database already has data, rerun with `SEED_FORCE=true`. Add `SEED_RESET=false`
  to keep existing rows while adding/updating seed records.
- Default seeding is destructive when `SEED_RESET` is `true` (wipes reviews, chats,
  jobs, services, users before recreating).
