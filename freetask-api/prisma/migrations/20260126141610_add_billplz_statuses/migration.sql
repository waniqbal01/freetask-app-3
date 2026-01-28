-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "WithdrawalStatus" ADD VALUE 'PAYOUT_PROCESSING';
ALTER TYPE "WithdrawalStatus" ADD VALUE 'PAYOUT_FAILED';

-- AlterTable
ALTER TABLE "Withdrawal" ADD COLUMN     "billplzPayoutId" TEXT,
ADD COLUMN     "lastAttemptAt" TIMESTAMP(3),
ADD COLUMN     "payoutError" TEXT;
