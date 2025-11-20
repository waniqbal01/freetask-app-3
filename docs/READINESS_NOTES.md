# Readiness Notes (Internal)

- **Backend:** `freetask-api` (NestJS + Prisma). Key modules: Auth, Users, Services, Jobs, Chats, Uploads, Notifications, Admin, Reviews, Reports, Health.
- **Flutter app:** `freetask_app` (GoRouter, repositories per feature). Main areas: Auth, Services, Jobs, Chat, Notifications, Admin, Reports/Reviews, Uploads.
- **Status before changes:** Contracts and seed data were inconsistent (mixed demo emails/passwords, job actions available in UI that backend would reject). CORS/env guidance and tester docs were fragmented, making it harder to run on emulator/web.
- **Status after changes:** Aligned API contracts with Flutter, refreshed deterministic seed/demo accounts, tightened job lifecycle guarding, and added focused testing docs (see [API_CONTRACT_MATRIX.md](API_CONTRACT_MATRIX.md) and [TESTING_GUIDE.md](TESTING_GUIDE.md)).
