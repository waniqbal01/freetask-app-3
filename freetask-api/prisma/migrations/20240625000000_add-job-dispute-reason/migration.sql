-- Add optional dispute reason to jobs
ALTER TABLE "Job"
  ADD COLUMN "disputeReason" TEXT DEFAULT NULL;
