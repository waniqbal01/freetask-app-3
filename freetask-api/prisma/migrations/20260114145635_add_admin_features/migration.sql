-- CreateEnum
CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "WithdrawalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterTable
ALTER TABLE "Service" ADD COLUMN     "approvalStatus" "ApprovalStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "rejectionReason" TEXT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "balance" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "isActive" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "Withdrawal" (
    "id" SERIAL NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "freelancerId" INTEGER NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "status" "WithdrawalStatus" NOT NULL DEFAULT 'PENDING',
    "bankDetails" JSONB NOT NULL,
    "processedAt" TIMESTAMP(3),
    "processedById" INTEGER,
    "rejectionReason" TEXT,

    CONSTRAINT "Withdrawal_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Withdrawal_freelancerId_idx" ON "Withdrawal"("freelancerId");

-- CreateIndex
CREATE INDEX "Withdrawal_status_idx" ON "Withdrawal"("status");

-- CreateIndex
CREATE INDEX "Service_approvalStatus_idx" ON "Service"("approvalStatus");

-- AddForeignKey
ALTER TABLE "Withdrawal" ADD CONSTRAINT "Withdrawal_freelancerId_fkey" FOREIGN KEY ("freelancerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Withdrawal" ADD CONSTRAINT "Withdrawal_processedById_fkey" FOREIGN KEY ("processedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
