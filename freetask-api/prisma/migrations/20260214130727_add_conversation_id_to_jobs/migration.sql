/*
  Warnings:

  - The values [DISPUTED,CANCELLED] on the enum `EscrowStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [ACCEPTED,CANCELLED,REJECTED] on the enum `JobStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [PROCESSING,REFUNDED] on the enum `PaymentStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [APPROVED,PAYOUT_PROCESSING,PAYOUT_FAILED] on the enum `WithdrawalStatus` will be removed. If these variants are still used in the database, this will fail.

*/
-- AlterEnum
BEGIN;
CREATE TYPE "EscrowStatus_new" AS ENUM ('PENDING', 'HELD', 'RELEASED', 'REFUNDED');
ALTER TABLE "Escrow" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Escrow" ALTER COLUMN "status" TYPE "EscrowStatus_new" USING ("status"::text::"EscrowStatus_new");
ALTER TYPE "EscrowStatus" RENAME TO "EscrowStatus_old";
ALTER TYPE "EscrowStatus_new" RENAME TO "EscrowStatus";
DROP TYPE "EscrowStatus_old";
ALTER TABLE "Escrow" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "JobStatus_new" AS ENUM ('INQUIRY', 'PENDING', 'AWAITING_PAYMENT', 'IN_PROGRESS', 'SUBMITTED', 'IN_REVIEW', 'COMPLETED', 'PAYOUT_PROCESSING', 'PAYOUT_HOLD', 'PAID_OUT', 'PAYOUT_FAILED', 'PAYOUT_FAILED_MANUAL', 'DISPUTED', 'CANCELED');
ALTER TABLE "Job" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Job" ALTER COLUMN "status" TYPE "JobStatus_new" USING ("status"::text::"JobStatus_new");
ALTER TYPE "JobStatus" RENAME TO "JobStatus_old";
ALTER TYPE "JobStatus_new" RENAME TO "JobStatus";
DROP TYPE "JobStatus_old";
ALTER TABLE "Job" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "PaymentStatus_new" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');
ALTER TABLE "Payment" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Payment" ALTER COLUMN "status" TYPE "PaymentStatus_new" USING ("status"::text::"PaymentStatus_new");
ALTER TYPE "PaymentStatus" RENAME TO "PaymentStatus_old";
ALTER TYPE "PaymentStatus_new" RENAME TO "PaymentStatus";
DROP TYPE "PaymentStatus_old";
ALTER TABLE "Payment" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "WithdrawalStatus_new" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'REJECTED');
ALTER TABLE "Withdrawal" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Withdrawal" ALTER COLUMN "status" TYPE "WithdrawalStatus_new" USING ("status"::text::"WithdrawalStatus_new");
ALTER TYPE "WithdrawalStatus" RENAME TO "WithdrawalStatus_old";
ALTER TYPE "WithdrawalStatus_new" RENAME TO "WithdrawalStatus";
DROP TYPE "WithdrawalStatus_old";
ALTER TABLE "Withdrawal" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- DropForeignKey
ALTER TABLE "Job" DROP CONSTRAINT "Job_serviceId_fkey";

-- AlterTable
ALTER TABLE "ChatMessage" ADD COLUMN     "conversationId" INTEGER,
ALTER COLUMN "jobId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "Job" ADD COLUMN     "conversationId" INTEGER,
ALTER COLUMN "serviceId" DROP NOT NULL;

-- CreateTable
CREATE TABLE "Conversation" (
    "id" SERIAL NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Conversation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "_ConversationToUser" (
    "A" INTEGER NOT NULL,
    "B" INTEGER NOT NULL
);

-- CreateIndex
CREATE UNIQUE INDEX "_ConversationToUser_AB_unique" ON "_ConversationToUser"("A", "B");

-- CreateIndex
CREATE INDEX "_ConversationToUser_B_index" ON "_ConversationToUser"("B");

-- CreateIndex
CREATE INDEX "ChatMessage_jobId_idx" ON "ChatMessage"("jobId");

-- CreateIndex
CREATE INDEX "ChatMessage_conversationId_idx" ON "ChatMessage"("conversationId");

-- AddForeignKey
ALTER TABLE "Job" ADD CONSTRAINT "Job_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Job" ADD CONSTRAINT "Job_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ConversationToUser" ADD CONSTRAINT "_ConversationToUser_A_fkey" FOREIGN KEY ("A") REFERENCES "Conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ConversationToUser" ADD CONSTRAINT "_ConversationToUser_B_fkey" FOREIGN KEY ("B") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
