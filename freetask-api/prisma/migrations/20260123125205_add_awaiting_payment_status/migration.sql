/*
  Warnings:

  - You are about to drop the column `savedBankAccounts` on the `User` table. All the data in the column will be lost.

*/
-- AlterEnum
ALTER TYPE "JobStatus" ADD VALUE 'AWAITING_PAYMENT';

-- AlterTable
ALTER TABLE "User" DROP COLUMN "savedBankAccounts";
