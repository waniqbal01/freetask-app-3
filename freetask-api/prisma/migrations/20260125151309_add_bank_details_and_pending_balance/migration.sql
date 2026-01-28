-- AlterTable
ALTER TABLE "User" ADD COLUMN     "bankAccount" TEXT,
ADD COLUMN     "bankCode" TEXT,
ADD COLUMN     "bankHolderName" TEXT,
ADD COLUMN     "bankVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "pendingBalance" DECIMAL(10,2) NOT NULL DEFAULT 0;
