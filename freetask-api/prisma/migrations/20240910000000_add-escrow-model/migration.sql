-- CreateEnum
CREATE TYPE "EscrowStatus" AS ENUM ('PENDING', 'HELD', 'RELEASED', 'REFUNDED');

-- CreateTable
CREATE TABLE "Escrow" (
    "id" SERIAL NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "jobId" INTEGER NOT NULL,
    "status" "EscrowStatus" NOT NULL DEFAULT 'PENDING',
    "amount" DECIMAL(10,2),

    CONSTRAINT "Escrow_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Escrow_jobId_key" ON "Escrow"("jobId");

-- AddForeignKey
ALTER TABLE "Escrow" ADD CONSTRAINT "Escrow_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "Job"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Backfill one-to-one escrow rows for existing jobs
INSERT INTO "Escrow" ("jobId", "status", "amount", "createdAt", "updatedAt")
SELECT "id" as "jobId", 'PENDING' as "status", "amount", NOW(), NOW()
FROM "Job"
ON CONFLICT ("jobId") DO NOTHING;
