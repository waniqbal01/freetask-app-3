-- AlterTable
ALTER TABLE "User" ADD COLUMN     "acceptsOutstation" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "coverageRadius" INTEGER,
ADD COLUMN     "district" TEXT,
ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION,
ADD COLUMN     "state" TEXT;
