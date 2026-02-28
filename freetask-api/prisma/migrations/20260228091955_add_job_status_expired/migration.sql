-- CreateEnum
CREATE TYPE "FreelancerLevel" AS ENUM ('NEWBIE', 'STANDARD', 'PRO');

-- AlterEnum
ALTER TYPE "JobStatus" ADD VALUE 'EXPIRED';

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "level" "FreelancerLevel" NOT NULL DEFAULT 'NEWBIE',
ADD COLUMN     "levelDowngradeStrikes" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "replyRate" DECIMAL(5,2),
ADD COLUMN     "totalCompletedJobs" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "totalIncomingRequests" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "totalRatingScore" DECIMAL(10,2) NOT NULL DEFAULT 0,
ADD COLUMN     "totalRepliedRequests" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "totalReviews" INTEGER NOT NULL DEFAULT 0;
