-- Create migration to add optional profile fields to the User table
ALTER TABLE "User"
  ADD COLUMN "avatarUrl" TEXT,
  ADD COLUMN "bio" TEXT,
  ADD COLUMN "skills" JSONB,
  ADD COLUMN "rate" DECIMAL(10,2);
