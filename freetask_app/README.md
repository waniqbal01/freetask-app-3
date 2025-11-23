# freetask_app

Flutter client for the FreeTask marketplace.

## Data sources

- **Backend (primary)**: authentication, profile, services, jobs, and chat all
  fetch from the API via `Dio`.
- **In-memory (temporary mocks)**: only `ReviewsRepository` and
  `EscrowService` keep local state for the MVP until their backend endpoints
  are available.

No other mock repositories should be added; new data flows should be wired to
the backend first.

## API base URLs

- **Android emulator:** `http://10.0.2.2:4000`
- **iOS simulator:** `http://localhost:4000`
- **Web/Desktop:** `http://localhost:4000`

Override by passing `--dart-define=API_BASE_URL=<url>` to `flutter run` or
`flutter build`. If the define is omitted, the defaults above are used per
platform.

When testing Flutter Web/Desktop locally, ensure the backend CORS origins include your
browser origin (e.g. `http://localhost:3000` or `http://localhost:5173`). The API ships
with sensible localhost defaults in `.env.example`.

### Running the Flutter app

```bash
flutter pub get

# Android emulator
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000

# Physical device or staging
flutter run --dart-define=API_BASE_URL=https://<your-host>

# Web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

If no `API_BASE_URL` is provided, the platform defaults above are used. Provide the
host that the device/browser can reach (e.g. LAN IP when testing on a phone).

Protected endpoints (jobs, chats, reviews, uploads) require a Bearer token set
via the app's authentication flow.

## Demo Accounts

Seed data ships with predictable credentials for quick QA:

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` (password `Password123!`)
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!`)

Use the "Demo Accounts" panel on the login screen to auto-fill these details.
