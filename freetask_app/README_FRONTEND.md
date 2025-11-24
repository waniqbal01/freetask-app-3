# Freetask Flutter QA Onboarding

## Setup

```bash
cd freetask_app
flutter pub get
```

## Running the app

- **Android emulator**: `flutter run -d emulator-5554`
- **iOS simulator**: `flutter run -d ios`
- **Web (Chrome)**: `flutter run -d chrome`

Default API base URLs:

- **Android emulator:** `http://10.0.2.2:4000`
- **Flutter web/desktop:** `http://localhost:4000`
- **iOS simulator:** `http://127.0.0.1:4000` (or your LAN IP)

You can override these at runtime without rebuilding, or via `--dart-define=API_BASE_URL=<url>` when launching.

### Changing API base URL at runtime

1. Open the app and tap **Tukar API Server** on the login screen (or **API Server** in the services list).
2. Enter the full base URL (e.g. `http://localhost:4000`, `http://10.0.2.2:4000`, or your LAN IP such as `http://192.168.0.10:4000`).
3. Save. The client will immediately use the new URL; clear the field to reset to the default.

### Common origins / CORS tips

Add your frontend origin to the API `ALLOWED_ORIGINS` if running the backend in production mode:

- Flutter web dev: `http://localhost:3000`
- Vite/other web dev: `http://localhost:5173`
- Android emulator webviews: `http://10.0.2.2:3000`
- iOS simulator/LAN: `http://127.0.0.1:4000` or `http://<your-ip>:4000`

Backend env snippets to copy into `.env`:

- **Local dev:**

  ```env
  PUBLIC_BASE_URL=http://localhost:4000
  ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://10.0.2.2:3000,http://localhost:4000,http://127.0.0.1:4000
  ```

- **Production web:**

  ```env
  PUBLIC_BASE_URL=https://api.freetask.my
  ALLOWED_ORIGINS=https://app.freetask.my,https://admin.freetask.my
  ```

Ensure the backend mounts/persists the `./uploads` folder (volume or host directory) so uploaded avatars/documents survive restarts.

### Demo credentials (from seed)

- Admin: `admin@example.com` / `Password123!`
- Clients: `client1@example.com`, `client2@example.com` / `Password123!`
- Freelancers: `freelancer1@example.com`, `freelancer2@example.com` / `Password123!`

#### Role-based guidance

- **CLIENT**: create orders from service detail → manage/cancel their own jobs only.
- **FREELANCER**: accept/start/complete/dispute jobs assigned to them; cannot cancel client jobs.
- **ADMIN**: read-only for most flows unless specific admin endpoints are exposed.

Tip: the login screen also links to **Tukar API Server** so testers can quickly set the correct base URL before using these demo accounts.

### Troubleshooting

- **CORS error on web**: ensure your origin is listed in `ALLOWED_ORIGINS` (backend `.env`) and restart the API.
- **Emulator cannot reach host**: use `http://10.0.2.2:4000` for Android; iOS simulator usually works with `http://localhost:4000` or your LAN IP.
- **Session expired**: the app will redirect to login; log in again after seeding.
