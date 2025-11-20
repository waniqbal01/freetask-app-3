# freetask_app

Flutter client for the Freetask marketplace (mobile + web).

## Quick Start

```bash
cd freetask_app
flutter pub get

# Android emulator (auto guna host 10.0.2.2)
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000

# Web / Chrome (gandingkan dengan backend di localhost)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000

# iOS simulator / desktop
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

- `API_BASE_URL` boleh diubah dengan `--dart-define` untuk sambung ke backend lain.
- Nilai lalai tanpa `--dart-define`: `http://10.0.2.2:4000` (Android), `http://localhost:4000` (web/iOS/desktop).

## Demo Akaun (daripada seed backend)
- Admin: `admin@demo.com / Admin123!`
- Client: `client@demo.com / Client123!`
- Freelancer: `freelancer@demo.com / Freelancer123!`

## Aliran Ujian Dicadangkan
- **Client**: log masuk → cari servis → tempah (POST /jobs) → terima job (PENDING → ACCEPTED) → chat → tanda selesai atau dispute.
- **Freelancer**: log masuk → pantau tab `Freelancer Jobs` → tolak (REJECTED) atau mula kerja (ACCEPTED → IN_PROGRESS) → tanda siap/dispute.
- **Admin**: log masuk → buka `/admin` untuk ringkasan health/stats.

## Error & Auth Handling
- 401 akan memaparkan mesej "Sesi anda telah tamat" sebelum pengguna dibawa ke skrin log masuk.
- Kesilapan `409 Conflict` (status job tidak sah) akan memaparkan mesej mesra agar pengguna menyegar semula status.

## Data sources

- **Backend (primary)**: authentication, profile, services, jobs, and chat all
  fetch from the API via `Dio`.
- **In-memory (temporary mocks)**: only `ReviewsRepository` and
  `EscrowService` keep local state for the MVP until their backend endpoints
  are available.

No other mock repositories should be added; new data flows should be wired to
the backend first.
