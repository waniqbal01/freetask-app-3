-- CreateEnum for MessageStatus
CREATE TYPE "MessageStatus" AS ENUM ('PENDING', 'SENT', 'DELIVERED', 'READ', 'FAILED');

-- AlterTable ChatMessage - Add new columns
ALTER TABLE "ChatMessage" ADD COLUMN "status" "MessageStatus" NOT NULL DEFAULT 'SENT';
ALTER TABLE "ChatMessage" ADD COLUMN "deliveredAt" TIMESTAMP(3);
ALTER TABLE "ChatMessage" ADD COLUMN "readAt" TIMESTAMP(3);
ALTER TABLE "ChatMessage" ADD COLUMN "replyToId" INTEGER;

-- CreateIndex for better query performance
CREATE INDEX "ChatMessage_status_idx" ON "ChatMessage"("status");
CREATE INDEX "ChatMessage_jobId_readAt_idx" ON "ChatMessage"("jobId", "readAt");

-- AddForeignKey for reply feature
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_replyToId_fkey" FOREIGN KEY ("replyToId") REFERENCES "ChatMessage"("id") ON DELETE SET NULL ON UPDATE CASCADE;
