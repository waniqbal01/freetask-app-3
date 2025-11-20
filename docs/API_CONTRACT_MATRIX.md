# API Contract Matrix (Backend ↔️ Flutter)

## Auth
- **Flutter:** `AuthRepository.login(email, password)` → **Backend:** `POST /auth/login`
  - Request: `{ email, password }`
  - Response: `{ accessToken: string, user: { id, name, email, role, avatarUrl?, bio?, skills?, rate? } }`
- **Flutter:** `AuthRepository.register(payload)` → **Backend:** `POST /auth/register`
  - Payload fields accepted: `email`, `password`, `name`, `role`, optional `avatar`/`avatarUrl`, `bio`, `skills` (string array), `rate`.
- **Flutter:** `AuthRepository.getCurrentUser()` → **Backend:** `GET /auth/me`
  - Response: same `user` shape as login.
- **Flutter:** `AuthRepository.logout()` → **Backend:** `POST /auth/logout` (stateless ok).

## Services
- **Flutter:** `ServicesRepository.getServices({ q, category, minPrice, maxPrice, minRating, maxDeliveryDays })` → **Backend:** `GET /services` with matching query params. Response includes `id`, `title`, `description`, `price`, `category`, `freelancer{id,name}`, `deliveryDays?`, `averageRating?`, `reviewCount?`.
- **Flutter:** `ServicesRepository.getServiceById(id)` → **Backend:** `GET /services/:id`.
- **Flutter:** `ServicesRepository.getCategories()` → **Backend:** `GET /services/categories`.
- **Flutter:** `ServicesRepository.fetchMyServices()` → **Backend:** `GET /services/mine` (freelancer auth required).
- **Flutter:** `ServicesRepository.createService(payload)` → **Backend:** `POST /services` (auth freelancer).
- **Flutter:** `ServicesRepository.updateService(id,payload)` → **Backend:** `PATCH /services/:id` (auth freelancer).
- **Flutter:** `ServicesRepository.deleteService(id)` → **Backend:** `DELETE /services/:id` (auth freelancer).

## Jobs & Lifecycle
- **Flutter:** `JobsRepository.createOrder(serviceId, amount?, description, title?)` → **Backend:** `POST /jobs` (client only). Response job includes `service`, `client`, `freelancer` ids/names and status.
- **Flutter:** `JobsRepository.getClientJobs()` / `getFreelancerJobs()` / `getAllJobs()` → **Backend:** `GET /jobs?filter=client|freelancer|all`.
- **Flutter:** `JobsRepository.getJobById(id)` → **Backend:** `GET /jobs/:id`.
- **Flutter:** `JobsRepository.getJobHistory(id)` → **Backend:** `GET /jobs/:id/history`.
- **Reference:** `GET /jobs/meta/statuses/flow` mirrors status carta aliran yang digunakan UI.
- **Status transitions (backend guarded & reflected in UI):**
  - `PENDING → ACCEPTED` (client) via `PATCH /jobs/:id/accept`.
  - `PENDING → REJECTED` (freelancer) via `PATCH /jobs/:id/reject`.
  - `ACCEPTED → IN_PROGRESS` (freelancer) via `PATCH /jobs/:id/start`.
  - `IN_PROGRESS → COMPLETED` (client or freelancer) via `PATCH /jobs/:id/complete`.
  - `ACCEPTED/IN_PROGRESS/COMPLETED → DISPUTED` (participant) via `PATCH /jobs/:id/dispute { reason }`.
- Invalid transitions return **409 Conflict** with a clear message.

## Chat
- **Flutter:** `ChatRepository.fetchThreads()` → **Backend:** `GET /chats` (auth).
- **Flutter:** `ChatRepository.streamMessages(jobId)` (REST load + socket) → **Backend:** `GET /chats/:jobId/messages`.
- **Flutter:** `ChatRepository.sendText/sendImage` → **Backend:** `POST /chats/:jobId/messages` body `{ content }`.
- **Socket namespace** `/chats` (best-effort): listens to `messageReceived` and `jobStatusUpdated` events with payload `{ id, content, senderId, jobId, createdAt, status?, disputeReason? }`.

## Notifications
- **Flutter:** `NotificationsRepository.getNotifications()` → **Backend:** `GET /notifications` (auth). Returns list with `id`, `title`, `body`, `type`, `metadata?`, `isRead`, `createdAt`.
- **Flutter:** `NotificationsRepository.markAsRead(id)` → **Backend:** `PATCH /notifications/:id/read`.

## Uploads
- **Flutter:** `UploadService.uploadFile(path)` → **Backend:** `POST /uploads` (multipart form field `file`, Bearer token). Response: `{ url: string }`; used for avatars and attachments.

## User Model (common fields)
`id`, `email`, `name`, `role`, optional `avatarUrl`, `bio`, `skills` (string[]), `rate` (number), timestamps when provided.
