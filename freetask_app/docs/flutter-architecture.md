# Flutter App Architecture

## Directory Structure
- `lib/core/` – Environment resolution (`env.dart`), global router (`router.dart`), theming, notifications helper, common widgets, and reusable state utilities.
- `lib/services/` – HTTP client and token storage built on Dio, upload service helpers, and Socket.io client setup.
- `lib/features/` – Feature-first folders:
  - `auth/` – Auth screens and `AuthRepository` for login/register/token refresh.
  - `home/` – Landing shell that wires the bottom navigation and dashboards.
  - `services/` – Browse, create, and edit freelancer services.
  - `jobs/` – Job list/detail screens and checkout helpers for hiring.
  - `chat/` – Chat threads and room UI for each job.
  - `payments/` and `checkout/` – Client checkout flow stubs ready to call payment intents.
  - `notifications/` – Notification feed and read-state updates.
  - `admin/` – Admin dashboard guarded by role.
  - `reviews/` – UI scaffolding for future review flow.
- `lib/models/` – Typed models for jobs, services, users, etc.
- `lib/widgets/` & `lib/core/widgets/` – Reusable cards, buttons, list views.
- `lib/theme/` – App-wide styles and color tokens.

## State Management
- The app uses **Riverpod**; providers typically live next to their feature code (e.g., auth providers next to `AuthRepository`).
- Repositories wrap Dio via the shared `HttpClient`, and providers expose asynchronous state for screens.
- Some legacy screens still leverage `StatefulWidget` for local form state, but network/stateful logic flows through providers to keep mutations predictable.

## Navigation
- Routing is centralized in `lib/core/router.dart` using **GoRouter**.
- Main routes include:
  - `/startup` splash & session bootstrap
  - `/` role selection, `/login`, `/register`
  - `/home` landing
  - `/services`, `/service/:id`, freelancer service CRUD routes
  - `/jobs`, `/jobs/:id`, `/jobs/checkout`
  - `/checkout` payment draft
  - `/chat`, `/chat/:id`
  - `/notifications`
  - `/admin` (redirects non-admins to `/home`)
- Role-aware redirects are applied for the admin route by checking `authRepository.currentUser?.role`.

## Data Layer
- `HttpClient` in `lib/services/http_client.dart` configures Dio with `API_BASE_URL` from `Env.apiBaseUrl`, attaches bearer tokens, and redirects to login on 401 responses.
- Feature repositories (e.g., `AuthRepository`, service/job repositories, chat repositories) encapsulate API calls and error mapping.
- Uploads use `UploadService` for multipart requests and integrate with the shared token storage.

## UI Conventions
- Screens generally follow `*Screen` naming; reusable chunks follow `*Card` or `*Tile` (e.g., service/job cards).
- Shared async UI helpers (like `AsyncState` utilities) live in `lib/core/state/`.
- Notification toasts/snackbars use `core/notifications/notification_service.dart`.

## Adding a New Feature
1. **API**: Add the backend endpoint if required (NestJS controller + service + DTO).
2. **Repository**: Create a repository method under the relevant feature folder that calls the API via `HttpClient`.
3. **Provider**: Expose state with Riverpod providers for fetching/mutations.
4. **UI**: Build screens/widgets in `lib/features/<feature>` and wire validation/async states to the provider.
5. **Routing**: Register the screen in `core/router.dart` and handle any role-based redirects.
6. **Testing**: Add widget or provider tests under the feature folder and run `flutter test`.
