# Panduan Ujian Freetask (MVP)

Dokumen ini menerangkan cara menjalankan backend + Flutter app, akaun demo, dan aliran ujian asas.

## 1) Prasyarat
- Node.js + npm
- PostgreSQL berjalan secara lokal (DB `freetask` atau ikut `DATABASE_URL`)
- Flutter SDK
- (Opsyenal) Android emulator / iOS simulator

## 2) Setup Backend (`freetask-api`)
```bash
cd freetask-api
cp .env.example .env
npm install
npm run db:setup    # jalankan migrasi + seed demo
npm run start:dev   # server pada http://localhost:4000
```
- Swagger: http://localhost:4000/api/docs
- Jika perlu, tambah URL frontend pada `ALLOWED_ORIGINS` dalam `.env`.

## 3) Akaun & Data Demo
Akaun dibuat oleh `npm run db:setup` (boleh dijalankan berulang, data idempotent):
- **Admin** — email: `admin@demo.com`, password: `Admin123!`
- **Client** — email: `client@demo.com`, password: `Client123!`
- **Freelancer** — email: `freelancer@demo.com`, password: `Freelancer123!`

Data tambahan:
- Servis contoh (Design, Development, Marketing) milik freelancer demo.
- Job dalam status PENDING/ACCEPTED/IN_PROGRESS/COMPLETED/DISPUTED dengan sejarah aktiviti.
- Beberapa mesej chat & notifikasi untuk skrin Chat/Notifications.

## 4) Jalankan Flutter App (`freetask_app`)
```bash
cd freetask_app
flutter pub get
```
- Android emulator: `flutter run -d emulator` (auto guna `http://10.0.2.2:4000`).
- Web/Chrome: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000`.
- iOS simulator / desktop: lalai `http://localhost:4000` (boleh override dengan `--dart-define`).

## 5) Aliran Ujian Dicadangkan
- **Client:** Log masuk → semak servis → tempah servis (buat job) → terima job (status ACCEPTED) → buka chat → tandakan selesai atau dispute.
- **Freelancer:** Log masuk → lihat My Services → pantau job masuk → tolak jika perlu → mula kerja (ACCEPTED → IN_PROGRESS) → tandakan selesai atau buka dispute.
- **Admin:** Log masuk → semak endpoint admin/health jika diperlukan.

## 6) Status Job & Peraturan Endpoint
- Status rasmi: PENDING, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED, REJECTED, DISPUTED.
- PENDING → ACCEPTED (client)
- PENDING → REJECTED (freelancer)
- ACCEPTED → IN_PROGRESS (freelancer)
- ACCEPTED/IN_PROGRESS → CANCELLED (rujuk API untuk kegunaan pentadbir)
- IN_PROGRESS → COMPLETED (client/freelancer)
- ACCEPTED/IN_PROGRESS/COMPLETED → DISPUTED (mana-mana peserta)
- Endpoint rujukan: `PATCH /jobs/:id/accept|reject|start|complete|dispute`, `GET /jobs/:id/history`, `GET /jobs/meta/statuses/flow` untuk carta aliran ringkas.

## 7) Chat & Realtime
- REST: `GET /chats`, `GET /chats/:jobId/messages`, `POST /chats/:jobId/messages` adalah sumber utama.
- Socket (namespace `/chats`) best-effort sahaja; UI kekal berfungsi dengan REST sekiranya realtime gagal.

## 8) Had Upload
- `POST /uploads` dengan medan `file`, saiz disyorkan ≤10MB, jenis umum: png/jpeg/pdf.
- Perlu header `Authorization: Bearer <token>`.

## 9) Had Diketahui
- Sistem pembayaran belum dilaksanakan.
- Modul Reviews/Reports asas sahaja.
