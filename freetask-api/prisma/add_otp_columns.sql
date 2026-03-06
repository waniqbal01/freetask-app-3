-- Safe: only adds columns if they don't already exist. No data will be lost.
ALTER TABLE "User"
  ADD COLUMN IF NOT EXISTS "isEmailVerified" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "otpCode" TEXT,
  ADD COLUMN IF NOT EXISTS "otpExpiresAt" TIMESTAMP(3);
