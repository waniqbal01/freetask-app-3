# Freetask API – Setup Guide

Dokumen ini membantu anda memulakan backend NestJS dengan cepat untuk ujian tempatan atau demo.

## 1. Prasyarat
- Node.js 20+
- PostgreSQL berjalan di mesin anda
- pnpm / npm / yarn (pilih satu pengurus pakej)

## 2. Clone & Install
```bash
git clone <REPO_URL>
cd freetask-app-3/freetask-api
npm install   # atau pnpm install / yarn
```

## 3. Konfigurasi Persekitaran
1. Salin contoh env:
   ```bash
   cp .env.example .env
   ```
2. Kemaskini nilai penting dalam `.env`:
   - `DATABASE_URL` – sambungan PostgreSQL (DB akan dicipta jika belum wujud)
   - `JWT_SECRET` – rahsia JWT
   - `HOST` & `PORT` – `0.0.0.0:4000` sesuai untuk Docker/VM
   - `ALLOWED_ORIGINS` – senarai origin dipisah koma untuk CORS (contoh: `http://localhost:3000`)
   - `APP_URL` (pilihan) – URL API untuk logging/CORS

## 4. Setup Pangkalan Data & Seed
Jalankan migrasi + seed demo (idempotent, selamat diulang):
```bash
npm run db:setup
```
Jika perlu jalankan secara berasingan:
```bash
npm run prisma:migrate
npm run prisma:seed
```

## 5. Jalankan Pelayan
```bash
npm run start:dev
```
- API: `http://localhost:4000`
- Swagger: `http://localhost:4000/api/docs`
- Healthcheck: `http://localhost:4000/health`

## 6. Demo Accounts (Prisma Seed)
Akaun di bawah dicipta oleh `npm run prisma:seed` untuk ujian pantas:
- **Admin** – Email: `admin@demo.com`, Password: `Admin123!`
- **Client** – Email: `client@demo.com`, Password: `Client123!`
- **Freelancer** – Email: `freelancer@demo.com`, Password: `Freelancer123!`

## 7. CORS & Host Tips
- CORS lalai meliputi `localhost`, `10.0.2.2` (Android emulator) dan port 5173 untuk Flutter web.
- Tambah origin lain melalui `ALLOWED_ORIGINS` dalam `.env` (pisahkan dengan koma).
- Tukar `HOST` kepada `127.0.0.1` jika hanya ingin bind ke loopback.

## 8. Skrip Bermanfaat
- `npm run start:dev` – jalankan API dengan reload pantas.
- `npm run build && npm run start` – bina dan jalankan versi produksi.
- `npm run prisma:generate` – jana Prisma client.
- `npm test` – jalankan ujian Jest.

## 9. Nota Penyelesaian Masalah
- Jika sambungan DB gagal, semak `DATABASE_URL` dan pastikan PostgreSQL menerima sambungan pada host/port tersebut.
- Jika CORS disekat, semak log konsol untuk senarai origin dibenarkan dan kemaskini `ALLOWED_ORIGINS`.
