-- Quick Setup Script - Create Enums First
-- Run this in Supabase SQL Editor BEFORE importing the main SQL file

-- Create all enum types required by the Freetask database
CREATE TYPE "UserRole" AS ENUM ('CLIENT', 'FREELANCER', 'ADMIN');

CREATE TYPE "JobStatus" AS ENUM (
  'PENDING',
  'AWAITING_PAYMENT', 
  'IN_PROGRESS',
  'SUBMITTED',
  'COMPLETED',
  'DISPUTED',
  'CANCELED'
);

CREATE TYPE "PaymentStatus" AS ENUM (
  'PENDING',
  'COMPLETED',
  'FAILED'
);

CREATE TYPE "EscrowStatus" AS ENUM (
  'PENDING',
  'HELD',
  'RELEASED',
  'REFUNDED'
);

CREATE TYPE "ApprovalStatus" AS ENUM (
  'PENDING',
  'APPROVED',
  'REJECTED'
);

CREATE TYPE "WithdrawalStatus" AS ENUM (
  'PENDING',
  'PROCESSING',
  'COMPLETED',
  'REJECTED'
);

-- Verify enums created
SELECT typname 
FROM pg_type 
WHERE typtype = 'e'
ORDER BY typname;
