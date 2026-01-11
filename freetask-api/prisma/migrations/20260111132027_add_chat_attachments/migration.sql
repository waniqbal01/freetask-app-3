-- AlterTable
ALTER TABLE "ChatMessage" ADD COLUMN     "attachmentUrl" TEXT,
ADD COLUMN     "type" TEXT NOT NULL DEFAULT 'text';
