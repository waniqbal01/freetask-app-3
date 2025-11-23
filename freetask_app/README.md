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

- **Android emulator:** `http://10.0.2.2:3000`
- **iOS simulator:** `http://localhost:3000`
- **Web/Desktop:** `http://localhost:3000`

Protected endpoints (jobs, chats, reviews, uploads) require a Bearer token set
via the app's authentication flow.
