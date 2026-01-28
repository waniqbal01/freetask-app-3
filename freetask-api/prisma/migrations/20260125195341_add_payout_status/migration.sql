-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "JobStatus" ADD VALUE 'PAYOUT_PROCESSING';
ALTER TYPE "JobStatus" ADD VALUE 'PAID_OUT';
ALTER TYPE "JobStatus" ADD VALUE 'PAYOUT_FAILED';

-- AlterTable
ALTER TABLE "Job" ADD COLUMN     "billplzPayoutId" TEXT,
ADD COLUMN     "freelancerPayoutAmount" DECIMAL(10,2),
ADD COLUMN     "platformFeeAmount" DECIMAL(10,2);
