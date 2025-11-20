# Operations

## Running in Development
- **Backend**: `cd freetask-api && npm install && npm run start:dev`
  - Exposes REST + WebSocket server on `PORT` (default `4000`).
  - Swagger UI available at `http://localhost:4000/api/docs`.
- **Flutter app**: `cd freetask_app && flutter pub get`
  - Android emulator: `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000`
  - Web/Chrome: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000`

## Database Migrations & Seed
- Configure `DATABASE_URL` in `freetask-api/.env`.
- Apply migrations: `npm run prisma:migrate` (runs `prisma migrate dev`).
- Generate client: `npm run prisma:generate`.
- Seed sample data: `npm run prisma:seed`.

## Deployment Overview
- **Backend**: Deploy as a Node service (e.g., Render/Railway/Fly). Provide `DATABASE_URL`, `JWT_SECRET`, `PORT`, and `ALLOWED_ORIGINS`. Expose `/uploads` for static files or swap storage for S3. Wire a PostgreSQL database and set up migrations on release.
- **Flutter Web**: Build with `flutter build web` and host the `build/web` folder (e.g., Vercel/Netlify/S3+CloudFront). Set `API_BASE_URL` via `--dart-define` or environment config.
- **Mobile apps**: Build with `flutter build apk` / `flutter build ipa` after pointing `API_BASE_URL` to the deployed backend.
- **Payments/Notifications**: Payment gateway webhooks and push notification credentials can be added later; leave TODOs for secrets in hosting providers.

## Monitoring & Logging
- The backend uses NestJS logger output; pipe logs to your platform (e.g., CloudWatch, LogDNA) in production.
- Add error monitoring (e.g., Sentry) by configuring DSNs in environment variables and bootstrapping a NestJS interceptor/provider.
- Socket.io logs can be enabled via `DEBUG=socket.io:*` when troubleshooting chat events.
