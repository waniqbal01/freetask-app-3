# Contributing to Freetask

## Development Environment
1. Clone the repo and follow the setup steps in the root README.
2. Create a PostgreSQL database and copy `freetask-api/.env.example` to `.env` with the correct `DATABASE_URL` and secrets.
3. Run the backend with `npm run start:dev` from `freetask-api` and the Flutter app with `flutter run --dart-define=API_BASE_URL=...` from `freetask_app`.
4. Keep backend and app running together to test end-to-end flows (auth → services → jobs → chat).

## Code Style
- **Backend (NestJS/TypeScript)**: Use ESLint/Prettier (`npm run lint`, `npm run format`). Prefer typed DTOs and avoid adding `any`. Keep imports ordered and avoid wrapping imports in try/catch.
- **Flutter/Dart**: Run `dart format .` and `flutter analyze` before committing. Follow feature-first folder structure and prefer Riverpod providers for shared state.

## Branching & Workflow
- Use feature branches from `main` (e.g., `feat/auth-refresh`, `fix/chat-scroll`).
- Submit a pull request for review; keep changes focused and describe user-facing impact.
- Rebase on `main` before merging to keep history linear.

## Testing Expectations
- **Backend**: `npm test` (unit/e2e) and run Prisma migrations against a test database when relevant.
- **Flutter**: `flutter test` for widget/provider tests. Add Golden tests for visual components when feasible.
- Include manual QA notes for flows you verified (e.g., registration + job creation).

## Commit Messages
- Prefer conventional prefixes (`feat:`, `fix:`, `chore:`, `docs:`) and concise descriptions.

## Issues & Templates
- If GitHub issue templates are added later, follow them for bug reports and feature requests. For now, include steps to reproduce, expected/actual behavior, and environment details.
