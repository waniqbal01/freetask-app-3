-- AlterEnum: Add missing JobStatus values for payout workflow
-- This migration adds 6 enum values that are used in the codebase but missing from the database

-- Add new enum values to JobStatus
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'IN_REVIEW';
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_PROCESSING';
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_HOLD';
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAID_OUT';
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_FAILED';
ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_FAILED_MANUAL';
