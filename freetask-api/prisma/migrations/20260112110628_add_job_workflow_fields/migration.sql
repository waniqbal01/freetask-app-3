-- AlterEnum
ALTER TYPE "JobStatus" ADD VALUE 'IN_REVIEW';

-- AlterTable
ALTER TABLE "Job" ADD COLUMN     "autoCompleteAt" TIMESTAMP(3),
ADD COLUMN     "orderAttachments" JSONB,
ADD COLUMN     "submissionAttachments" JSONB,
ADD COLUMN     "submissionMessage" TEXT,
ADD COLUMN     "submittedAt" TIMESTAMP(3);
