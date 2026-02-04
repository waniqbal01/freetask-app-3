import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Connecting to database...');
    try {
        console.log('Adding IN_REVIEW...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'IN_REVIEW';`);

        console.log('Adding PAYOUT_PROCESSING...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_PROCESSING';`);

        console.log('Adding PAYOUT_HOLD...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_HOLD';`);

        console.log('Adding PAID_OUT...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAID_OUT';`);

        console.log('Adding PAYOUT_FAILED...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_FAILED';`);

        console.log('Adding PAYOUT_FAILED_MANUAL...');
        await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS 'PAYOUT_FAILED_MANUAL';`);

        console.log('✅ Enum values added successfully!');
    } catch (e) {
        console.error('❌ Error adding enum values:', e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
