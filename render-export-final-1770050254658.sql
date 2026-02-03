-- Freetask Database Export from Render
-- Generated: 2026-02-02T16:37:33.943Z
-- Tables: 14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';


-- Table: AdminLog
DROP TABLE IF EXISTS "AdminLog" CASCADE;
CREATE TABLE "AdminLog" (
  "id" integer NOT NULL DEFAULT nextval('"AdminLog_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "adminId" integer NOT NULL,
  "action" text NOT NULL,
  "resource" text,
  "details" jsonb
);

INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (1, '2026-01-31T05:42:32.192Z', 1, 'VIEW_ANALYTICS', 'analytics', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (2, '2026-01-31T05:42:32.540Z', 1, 'VIEW_STATS', 'stats', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (3, '2026-01-31T05:42:37.031Z', 1, 'VIEW_USERS', 'users', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (4, '2026-01-31T05:42:39.127Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (5, '2026-01-31T05:42:42.156Z', 1, 'APPROVE_SERVICE', 'service', '{"serviceId":6}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (6, '2026-01-31T05:42:42.221Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (7, '2026-01-31T05:43:09.045Z', 1, 'REJECT_SERVICE', 'service', '{"reason":"dah ada","serviceId":5}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (8, '2026-01-31T05:43:09.089Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (9, '2026-01-31T05:43:14.481Z', 1, 'REJECT_SERVICE', 'service', '{"reason":"dah ada","serviceId":4}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (10, '2026-01-31T05:43:14.556Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (11, '2026-01-31T05:43:19.940Z', 1, 'APPROVE_SERVICE', 'service', '{"serviceId":3}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (12, '2026-01-31T05:43:20.010Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (13, '2026-01-31T05:43:25.411Z', 1, 'REJECT_SERVICE', 'service', '{"reason":"dah ada","serviceId":2}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (14, '2026-01-31T05:43:25.474Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (15, '2026-01-31T05:43:32.546Z', 1, 'REJECT_SERVICE', 'service', '{"reason":"dah ada","serviceId":1}');
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (16, '2026-01-31T05:43:32.611Z', 1, 'VIEW_PENDING_SERVICES', 'services', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (17, '2026-01-31T05:43:36.659Z', 1, 'VIEW_ORDERS', 'orders', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (18, '2026-01-31T05:43:37.469Z', 1, 'VIEW_WITHDRAWALS', 'withdrawals', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (19, '2026-01-31T05:43:37.543Z', 1, 'VIEW_WITHDRAWALS', 'withdrawals', NULL);
INSERT INTO "AdminLog" ("id", "createdAt", "adminId", "action", "resource", "details") VALUES (20, '2026-01-31T05:43:38.335Z', 1, 'VIEW_DISPUTES', 'disputes', NULL);


-- Table: ChatMessage
DROP TABLE IF EXISTS "ChatMessage" CASCADE;
CREATE TABLE "ChatMessage" (
  "id" integer NOT NULL DEFAULT nextval('"ChatMessage_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "content" text NOT NULL,
  "senderId" integer NOT NULL,
  "jobId" integer NOT NULL,
  "attachmentUrl" text,
  "type" text NOT NULL DEFAULT 'text'::text
);


-- Table: DeviceToken
DROP TABLE IF EXISTS "DeviceToken" CASCADE;
CREATE TABLE "DeviceToken" (
  "id" integer NOT NULL DEFAULT nextval('"DeviceToken_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "userId" integer NOT NULL,
  "token" text NOT NULL,
  "platform" text
);


-- Table: Escrow
DROP TABLE IF EXISTS "Escrow" CASCADE;
CREATE TABLE "Escrow" (
  "id" integer NOT NULL DEFAULT nextval('"Escrow_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "jobId" integer NOT NULL,
  "status" "EscrowStatus" NOT NULL DEFAULT 'PENDING'::"EscrowStatus",
  "amount" numeric
);


-- Table: Job
DROP TABLE IF EXISTS "Job" CASCADE;
CREATE TABLE "Job" (
  "id" integer NOT NULL DEFAULT nextval('"Job_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "title" text NOT NULL,
  "description" text NOT NULL,
  "amount" numeric NOT NULL,
  "status" "JobStatus" NOT NULL DEFAULT 'PENDING'::"JobStatus",
  "disputeReason" text,
  "serviceId" integer NOT NULL,
  "clientId" integer NOT NULL,
  "freelancerId" integer NOT NULL,
  "autoCompleteAt" timestamp,
  "orderAttachments" jsonb,
  "submissionAttachments" jsonb,
  "submissionMessage" text,
  "submittedAt" timestamp,
  "billplzPayoutId" text,
  "freelancerPayoutAmount" numeric,
  "platformFeeAmount" numeric,
  "payoutHoldReason" text,
  "payoutRetryCount" integer NOT NULL DEFAULT 0,
  "startedAt" timestamp
);


-- Table: Notification
DROP TABLE IF EXISTS "Notification" CASCADE;
CREATE TABLE "Notification" (
  "id" integer NOT NULL DEFAULT nextval('"Notification_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "userId" integer NOT NULL,
  "title" text NOT NULL,
  "body" text NOT NULL,
  "read" boolean NOT NULL DEFAULT false,
  "type" text,
  "data" jsonb
);


-- Table: Payment
DROP TABLE IF EXISTS "Payment" CASCADE;
CREATE TABLE "Payment" (
  "id" integer NOT NULL DEFAULT nextval('"Payment_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "jobId" integer NOT NULL,
  "amount" numeric NOT NULL,
  "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING'::"PaymentStatus",
  "paymentMethod" text,
  "transactionId" text,
  "paymentGateway" text
);


-- Table: PortfolioItem
DROP TABLE IF EXISTS "PortfolioItem" CASCADE;
CREATE TABLE "PortfolioItem" (
  "id" integer NOT NULL DEFAULT nextval('"PortfolioItem_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "title" text NOT NULL,
  "description" text,
  "category" text,
  "mediaUrl" text,
  "freelancerId" integer NOT NULL
);


-- Table: Review
DROP TABLE IF EXISTS "Review" CASCADE;
CREATE TABLE "Review" (
  "id" integer NOT NULL DEFAULT nextval('"Review_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "rating" integer NOT NULL,
  "comment" text,
  "jobId" integer NOT NULL,
  "reviewerId" integer NOT NULL,
  "revieweeId" integer NOT NULL
);


-- Table: Service
DROP TABLE IF EXISTS "Service" CASCADE;
CREATE TABLE "Service" (
  "id" integer NOT NULL DEFAULT nextval('"Service_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "title" text NOT NULL,
  "description" text NOT NULL,
  "price" numeric NOT NULL,
  "category" text NOT NULL,
  "freelancerId" integer NOT NULL,
  "thumbnailUrl" text,
  "deliveryTime" text,
  "isActive" boolean NOT NULL DEFAULT true,
  "approvalStatus" "ApprovalStatus" NOT NULL DEFAULT 'PENDING'::"ApprovalStatus",
  "rejectionReason" text
);

INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (6, '2026-01-23T03:07:33.720Z', '2026-01-31T05:42:42.153Z', 'cipta logo', 'cipta logo minimalist', '100.00', 'Design & Creative', 2, '/uploads/public/b271e982-2ec5-49ff-a7d2-4a972b9fe592.jpg', NULL, true, 'APPROVED', NULL);
INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (5, '2026-01-22T07:24:04.718Z', '2026-01-31T05:43:09.041Z', 'cipta logo', 'cipta logo minimalist', '100.00', 'Design & Creative', 2, '/uploads/public/6ba4d1ed-0089-4230-932d-efb6c46b8dc6.jpg', NULL, true, 'REJECTED', 'dah ada');
INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (4, '2026-01-22T07:12:46.906Z', '2026-01-31T05:43:14.476Z', 'cipta logo', 'menghasilkan logo minimalist', '100.00', 'Design & Creative', 2, '/uploads/public/3d0fcb0d-2e54-4202-9cdd-255bd1506a84.jpg', NULL, true, 'REJECTED', 'dah ada');
INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (3, '2026-01-22T07:11:37.164Z', '2026-01-31T05:43:19.937Z', 'poster design', 'menghasilkan 2-5 poster untuk kempen pemasaran anda . 
Design akan mengikut kreteria yang anda perlukan dan tetapkan. 
Masa siap dalam 1-3 hari bergantung pada rundingan dengan client.', '70.00', 'Design & Creative', 2, '/uploads/public/37f0227d-519e-46a8-87b8-deb4d3365f73.jpg', NULL, true, 'APPROVED', NULL);
INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (2, '2026-01-22T05:30:39.004Z', '2026-01-31T05:43:25.405Z', 'buat poster', 'Menghasilkan 2-5 poster yang sesuai untuk kempen pemasaran anda

- Hasilkan design berkualiti mengikut keperluan client
- Ambil masa 1-3 hari bergantung pada rundingan dengan client
- Memastikan design mengikut pilihan yang telah ditetapkan', '70.00', 'Design & Creative', 2, '/uploads/public/1ab45608-9f0a-48c0-b9ca-bfbb1f60655d.png', NULL, true, 'REJECTED', 'dah ada');
INSERT INTO "Service" ("id", "createdAt", "updatedAt", "title", "description", "price", "category", "freelancerId", "thumbnailUrl", "deliveryTime", "isActive", "approvalStatus", "rejectionReason") VALUES (1, '2026-01-21T06:39:31.410Z', '2026-01-31T05:43:32.542Z', 'buat poster untuk kempen', 'menghasilkan 2-5 poster untuk campaign rasmi pemasaran anda 

• design berkualiti
• Boleh direview banyak kali
• Mengikut keperluan client

tempoh masa 1-3 hari bergantung pada hasil perbicangan dengan client', '70.00', 'Design & Creative', 2, '/uploads/public/71af8c3f-393d-4960-9878-96cda23717b8.jpg', NULL, true, 'REJECTED', 'dah ada');


-- Table: Session
DROP TABLE IF EXISTS "Session" CASCADE;
CREATE TABLE "Session" (
  "id" integer NOT NULL DEFAULT nextval('"Session_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "userId" integer NOT NULL,
  "refreshTokenHash" text,
  "refreshTokenExpiresAt" timestamp NOT NULL,
  "revoked" boolean NOT NULL DEFAULT false,
  "lastIp" text,
  "userAgent" text
);

INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (1, '2026-01-21T06:26:14.138Z', '2026-01-21T06:32:43.982Z', 1, NULL, '2026-01-28T06:26:13.550Z', true, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (3, '2026-01-22T05:26:28.733Z', '2026-01-22T05:27:05.762Z', 1, NULL, '2026-01-29T05:26:28.226Z', true, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (4, '2026-01-22T05:27:19.333Z', '2026-01-22T05:27:19.333Z', 2, '$2a$10$XbaEpmM2EYKVeEA.DlQHIuqCAMmy1fOeQpLRPkrrd024jImzH1GAe', '2026-01-29T05:27:18.827Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (2, '2026-01-21T06:34:38.645Z', '2026-01-22T05:31:54.831Z', 2, '$2a$10$.VLUjQ085rtRW8QaSf1uB.XZIGGc9pKLy11rTmwrN1Yb/4llQl3Ja', '2026-01-29T05:31:54.331Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (5, '2026-01-22T07:08:51.958Z', '2026-01-22T07:09:05.634Z', 1, NULL, '2026-01-29T07:08:51.450Z', true, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (6, '2026-01-22T07:09:26.253Z', '2026-01-22T07:09:26.253Z', 2, '$2a$10$opRS91xJj9iIkFYlfzHR8.sxWwM3JZ.JTpSPL3.Mx9hPb/XWbwEMi', '2026-01-29T07:09:25.750Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (7, '2026-01-23T02:49:20.275Z', '2026-01-23T03:07:27.310Z', 2, '$2a$10$lDY6w8qZpmt8O1V1Ht00nOBpovMrZ9U1EotwhUR44FeracKm24BMy', '2026-01-30T03:07:26.808Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (8, '2026-01-31T04:56:58.624Z', '2026-01-31T04:56:58.624Z', 2, '$2a$10$Q5YIWnoZNXXWD0Q1uJRPFeuarifEkPlNrHKP1.xpSDeBPAcQPlxZi', '2026-02-07T04:56:58.117Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (9, '2026-01-31T05:41:54.569Z', '2026-01-31T05:42:23.097Z', 2, NULL, '2026-02-07T05:41:54.067Z', true, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (10, '2026-01-31T05:42:31.966Z', '2026-01-31T05:42:31.966Z', 1, '$2a$10$eUN6NIcF16bMkRDGB13kD.eK9d3gKrBBQIAmo00h0mNeGSc94.lai', '2026-02-07T05:42:31.465Z', false, NULL, NULL);
INSERT INTO "Session" ("id", "createdAt", "updatedAt", "userId", "refreshTokenHash", "refreshTokenExpiresAt", "revoked", "lastIp", "userAgent") VALUES (11, '2026-01-31T05:43:48.378Z', '2026-01-31T05:43:48.378Z', 2, '$2a$10$Ana9wCVeByGEsMQbmXXZb.gXgxJrH8BlCim2dgOitWRAdjBAx4s7e', '2026-02-07T05:43:47.874Z', false, NULL, NULL);


-- Table: User
DROP TABLE IF EXISTS "User" CASCADE;
CREATE TABLE "User" (
  "id" integer NOT NULL DEFAULT nextval('"User_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "email" text NOT NULL,
  "password" text NOT NULL,
  "name" text NOT NULL,
  "role" "UserRole" NOT NULL,
  "avatarUrl" text,
  "bio" text,
  "skills" jsonb,
  "rate" numeric,
  "isAvailable" boolean NOT NULL DEFAULT true,
  "location" text,
  "phoneNumber" text,
  "balance" numeric NOT NULL DEFAULT 0,
  "isActive" boolean NOT NULL DEFAULT true,
  "bankAccount" text,
  "bankCode" text,
  "bankHolderName" text,
  "bankVerified" boolean NOT NULL DEFAULT false,
  "pendingBalance" numeric NOT NULL DEFAULT 0,
  "trustScore" integer NOT NULL DEFAULT 50
);

INSERT INTO "User" ("id", "createdAt", "updatedAt", "email", "password", "name", "role", "avatarUrl", "bio", "skills", "rate", "isAvailable", "location", "phoneNumber", "balance", "isActive", "bankAccount", "bankCode", "bankHolderName", "bankVerified", "pendingBalance", "trustScore") VALUES (2, '2026-01-21T06:34:38.140Z', '2026-01-21T06:40:02.139Z', 'waniqbal@gmail.com', '$2a$10$WBLVHG6X6ugB/q6MkXbUPeScKzV9RYCjfYTAKUhP.sXoAWNz1Hehm', 'iqbal', 'FREELANCER', '/uploads/public/7d2a537e-9283-442c-b3a7-df0620b1011d.jpg', 'mahir dalam design dan it', '["buat poster Dan logo"]', NULL, true, NULL, NULL, '0.00', true, NULL, NULL, NULL, false, '0.00', 50);
INSERT INTO "User" ("id", "createdAt", "updatedAt", "email", "password", "name", "role", "avatarUrl", "bio", "skills", "rate", "isAvailable", "location", "phoneNumber", "balance", "isActive", "bankAccount", "bankCode", "bankHolderName", "bankVerified", "pendingBalance", "trustScore") VALUES (1, '2026-01-21T06:26:13.546Z', '2026-01-31T05:37:49.037Z', 'wmiqbal01@gmail.com', '$2a$10$7yXFsw9wab.Gu8vBMYDk7u7VeINKoNLuJ5ioZuX/wMGhAZcaZ6GFS', 'wan iqbal', 'ADMIN', '/uploads/public/aaff36cb-fd10-4243-baa7-5f154cc09009.jpg', NULL, NULL, NULL, true, 'johor', NULL, '0.00', true, NULL, NULL, NULL, false, '0.00', 50);


-- Table: Withdrawal
DROP TABLE IF EXISTS "Withdrawal" CASCADE;
CREATE TABLE "Withdrawal" (
  "id" integer NOT NULL DEFAULT nextval('"Withdrawal_id_seq"'::regclass),
  "createdAt" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp NOT NULL,
  "freelancerId" integer NOT NULL,
  "amount" numeric NOT NULL,
  "status" "WithdrawalStatus" NOT NULL DEFAULT 'PENDING'::"WithdrawalStatus",
  "bankDetails" jsonb NOT NULL,
  "processedAt" timestamp,
  "processedById" integer,
  "rejectionReason" text,
  "billplzPayoutId" text,
  "lastAttemptAt" timestamp,
  "payoutError" text
);


-- Table: _prisma_migrations
DROP TABLE IF EXISTS "_prisma_migrations" CASCADE;
CREATE TABLE "_prisma_migrations" (
  "id" varchar(36) NOT NULL,
  "checksum" varchar(64) NOT NULL,
  "finished_at" timestamptz,
  "migration_name" varchar(255) NOT NULL,
  "logs" text,
  "rolled_back_at" timestamptz,
  "started_at" timestamptz NOT NULL DEFAULT now(),
  "applied_steps_count" integer NOT NULL DEFAULT 0
);

INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('7a196935-ba5f-4a0a-b42a-4efd0bffaa79', 'a2344f92c6ae8ee951fe76dd3ae153b6a876dad0a5a2d2a8a72a1ae9e50bdddf', '2026-01-28T13:37:48.214Z', '20260122112551_add_saved_bank_accounts', NULL, NULL, '2026-01-28T13:37:48.136Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('89657c80-b26d-4cf1-83da-f6992f5d4760', '8e8421c26f658e98e8d98235f53f8f39c19b4c130825b47d4a173dea8ae86d24', NULL, '20240521000000_add-user-profile-fields', 'A migration failed to apply. New migrations cannot be applied before the error is recovered from. Read more about how to resolve migration issues in a production database: https://pris.ly/d/migrate-resolve

Migration name: 20240521000000_add-user-profile-fields

Database error code: 42P01

Database error:
ERROR: relation "User" does not exist

DbError { severity: "ERROR", parsed_severity: Some(Error), code: SqlState(E42P01), message: "relation \"User\" does not exist", detail: None, hint: None, position: None, where_: None, schema: None, table: None, column: None, datatype: None, constraint: None, file: Some("namespace.c"), line: Some(636), routine: Some("RangeVarGetRelidExtended") }

   0: sql_schema_connector::apply_migration::apply_script
           with migration_name="20240521000000_add-user-profile-fields"
             at schema-engine/connectors/sql-schema-connector/src/apply_migration.rs:106
   1: schema_core::commands::apply_migrations::Applying migration
           with migration_name="20240521000000_add-user-profile-fields"
             at schema-engine/core/src/commands/apply_migrations.rs:91
   2: schema_core::state::ApplyMigrations
             at schema-engine/core/src/state.rs:226', '2026-01-07T14:13:42.008Z', '2026-01-07T13:22:21.687Z', 0);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('5ec54e45-0f6e-4d27-ae03-c14a915edca0', 'b02af172f6befa6906ac1c372cc5bafc6bc9498bb43cd6ab421aee002d7beb96', '2026-01-07T14:21:30.198Z', '20240101000000_init', NULL, NULL, '2026-01-07T14:21:29.782Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('4ef91ff1-fa51-4165-a469-799e8958638b', '5a8b2466bb8fb930ce910e99efb145c2105b71ebd0a9a4bd84147cf1052ddf39', '2026-01-08T07:05:12.023Z', '20260108055427_restore_missing_features', NULL, NULL, '2026-01-08T07:05:11.926Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('fa50d699-7aed-4d83-a5b3-5ae9c759844a', '50228ebe6d2ee528d448eecb1ebb551a3607b963a1248996a7fdebc28cd91ddb', '2026-01-28T13:37:48.226Z', '20260123125205_add_awaiting_payment_status', NULL, NULL, '2026-01-28T13:37:48.217Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('426117f5-0e50-41c2-9812-35e33fa26016', '8c2c413ab4c39e486a19bf45b7bc6466c68c7dbda2abd77ed60a3bde07b9c9df', '2026-01-11T13:33:49.810Z', '20260111132027_add_chat_attachments', NULL, NULL, '2026-01-11T13:33:49.781Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('585710de-fb5d-4ffa-9bbd-d9584cc48ffa', '6c10cbac075e5bdebe2c47c796995566dfe5845e974b0a68d7c85f78424316f0', '2026-01-12T03:44:55.412Z', '20260112033521_add_user_availability', NULL, NULL, '2026-01-12T03:44:55.325Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('d31a7647-598a-4f4e-8570-119c88e1f904', '8415d615e386d1d8a4403c9ce68ce39c1016eedc4478dad9b8eb88cdc4d4da5e', '2026-01-12T12:42:23.106Z', '20260112110628_add_job_workflow_fields', NULL, NULL, '2026-01-12T12:42:23.097Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('89c2e7ab-179d-4c93-abee-4d286554a063', '46d0fca1a8bb737aae402c2d7c09543603341ce2858ba9e3b909fa27532981ad', '2026-01-28T13:37:48.237Z', '20260125151309_add_bank_details_and_pending_balance', NULL, NULL, '2026-01-28T13:37:48.228Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('a6c015a3-a042-42e6-ac9a-6450716b5aba', '29f74a7f273145d1d71ffb65252a7ef49359d43103a3987605fd993c1a2442c6', '2026-01-21T13:12:03.114Z', '20260114145635_add_admin_features', NULL, NULL, '2026-01-21T13:12:03.054Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('d9b29d78-78ba-4808-9b9a-2c136fbb3eff', '14465bb09e0ece8cacea5b02a9c2a2dc52d27646bdff50c34ab49beb8b520511', '2026-01-21T13:12:03.156Z', '20260117122623_add_job_performance_indexes', NULL, NULL, '2026-01-21T13:12:03.120Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('a7c1609e-bd01-440d-9946-f8ab583dbfa0', 'c999a3ab2e479a142f7ba3d7e8184290e7c303400421aceb1173d8f9d93ddb85', '2026-01-28T13:37:48.251Z', '20260125195341_add_payout_status', NULL, NULL, '2026-01-28T13:37:48.241Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('507e7aa3-8bb3-44ef-b8a3-5e0abe1a8e3b', 'dc288a985b2afe949145b77015fa805a458f292a27ed43d27ec06adee5fcbdb6', '2026-01-28T13:37:48.314Z', '20260126104344_add_immediate_payout_features', NULL, NULL, '2026-01-28T13:37:48.253Z', 1);
INSERT INTO "_prisma_migrations" ("id", "checksum", "finished_at", "migration_name", "logs", "rolled_back_at", "started_at", "applied_steps_count") VALUES ('fd7db36d-f429-4acb-83f8-da811acf20d8', 'a3a7078a9dadd3c204dbc5e35fe51521f54187d0c609f24244a1324bc167b161', '2026-01-28T13:37:48.327Z', '20260126141610_add_billplz_statuses', NULL, NULL, '2026-01-28T13:37:48.316Z', 1);

