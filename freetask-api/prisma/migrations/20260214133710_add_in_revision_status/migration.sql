-- AlterEnum
ALTER TYPE "JobStatus" ADD VALUE 'IN_REVISION';

-- AlterTable
ALTER TABLE "Job" ADD COLUMN     "revisionCount" INTEGER NOT NULL DEFAULT 0;
