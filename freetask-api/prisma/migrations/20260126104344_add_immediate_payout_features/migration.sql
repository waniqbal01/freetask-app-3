-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "JobStatus" ADD VALUE 'PAYOUT_HOLD';
ALTER TYPE "JobStatus" ADD VALUE 'PAYOUT_FAILED_MANUAL';

-- AlterTable
ALTER TABLE "Job" ADD COLUMN     "payoutHoldReason" TEXT,
ADD COLUMN     "payoutRetryCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "startedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "trustScore" INTEGER NOT NULL DEFAULT 50;
