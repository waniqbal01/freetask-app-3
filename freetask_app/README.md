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

Protected endpoints (jobs, chats, reviews, uploads) require a Bearer token set
via the app's authentication flow.

## Demo Accounts

Seed data ships with predictable credentials for quick QA:

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` (password `Password123!`)
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` (password `Password123!`)

Use the "Demo Accounts" panel on the login screen to auto-fill these details.
