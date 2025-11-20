# Panduan Ujian Freetask (MVP)

Dokumen ini membantu tester menyediakan persekitaran backend/frontend, menggunakan akaun demo, dan memahami flow asas.

## 1) Setup Backend (freetask-api)

1. Salin contoh env:
   ```bash
   cd freetask-api
   cp .env.example .env
   ```
2. Isi nilai penting dalam `.env`:
   - `DATABASE_URL` = sambungan PostgreSQL anda.
   - `JWT_SECRET` dan `JWT_EXPIRES_IN` mengikut keperluan.
   - `ALLOWED_ORIGINS` (contoh: `http://localhost:3000,http://localhost:5173`).
3. Jalankan migrasi (manual oleh manusia):
   ```bash
   npx prisma migrate dev
   ```
4. Jalankan seed demo (manual oleh manusia):
   ```bash
   npm run prisma:seed
   ```

## 2) Akaun Demo

Semua kata laluan demo: **password123**

| Peranan      | Emel                 | Nota ringkas |
| ------------ | ------------------- | ------------ |
| Client       | client@test.com     | Boleh cipta job, terima/complain job, lengkapkan job. |
| Freelancer   | freelancer@test.com | Boleh cipta servis, mulakan/reject job, lengkapkan/dispute job. |
| Admin        | admin@test.com      | Boleh log masuk ke `/admin` untuk semakan asas admin. |

## 3) Flow Ujian Asas

- **Sebagai Client**: Login → semak senarai servis → create job → accept job → buka chat → mark complete/dispute jika perlu.
- **Sebagai Freelancer**: Login → tambah servis sendiri → lihat job yang masuk → start/reject job → chat → complete/dispute.
- **Sebagai Admin**: Login → akses `/admin` untuk semakan ringkas panel pentadbir.

## 4) Status Job & Peranan Endpoint

- Status utama: `PENDING → ACCEPTED → IN_PROGRESS → COMPLETED` (dengan kemungkinan `REJECTED`, `CANCELLED`, `DISPUTED`).
- Endpoints peranan (ringkas):
  - `POST /jobs` (client sahaja)
  - `PATCH /jobs/:id/accept` (client sahaja)
  - `PATCH /jobs/:id/start` (freelancer sahaja)
  - `PATCH /jobs/:id/reject` (freelancer sahaja)
  - `PATCH /jobs/:id/complete` (client atau freelancer)
  - `PATCH /jobs/:id/dispute` (client atau freelancer, body `{ reason }`).

## 5) Chat Behavior

- HTTP adalah sumber utama:
  - `GET /chats` (senarai thread)
  - `GET /chats/:jobId/messages`
  - `POST /chats/:jobId/messages`
- Socket (`/chats` namespace) adalah tambahan realtime sahaja. UI kekal berfungsi dengan REST walaupun socket gagal; guna pull-to-refresh jika perlu.

## 6) Had Upload Ringkas

- Jenis fail disokong lazim: PNG / JPEG / PDF.
- Saiz cadangan: ≤ 10MB per fail.
- Semua muat naik memerlukan `Authorization: Bearer <token>`.

## 7) Tetapan Frontend (freetask_app)

- `Env.apiBaseUrl` automatik memilih host:
  - Web/iOS/Desktop: `http://localhost:4000`
  - Android emulator: `http://10.0.2.2:4000`
- Untuk deep-link job detail: `/jobs/<id>` akan memuat semula data jika tiada objek job diberikan.

