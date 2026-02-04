
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Starting Fix Script...');

    try {
        // 1. Test Connection
        console.log('Testing connection with SELECT 1...');
        const result = await prisma.$queryRaw`SELECT 1 as result`;
        console.log('✅ Connection Successful:', result);

        // 2. Apply Fixes
        console.log('Applying Enum Fixes...');

        // We use a helper to catch individual errors (e.g. if value already exists)
        const addValue = async (val: string) => {
            try {
                console.log(`Adding ${val}...`);
                await prisma.$executeRawUnsafe(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS '${val}'`);
                console.log(`  ✅ Added ${val}`);
            } catch (e: any) {
                // Postgres error 25001: ALTER TYPE ... cannot run inside a transaction block
                // Prisma might wrap queries in transaction?
                console.error(`  ⚠️  Failed to add ${val}: ${e.message}`, e);
            }
        };

        const values = [
            'IN_REVIEW',
            'PAYOUT_PROCESSING',
            'PAYOUT_HOLD',
            'PAID_OUT',
            'PAYOUT_FAILED',
            'PAYOUT_FAILED_MANUAL'
        ];

        for (const val of values) {
            await addValue(val);
        }

        console.log('🎉 Fix Script Completed');
    } catch (e: any) {
        console.error('❌ Critical Error:', e);
        process.exit(1);
    } finally {
        await prisma.$disconnect();
    }
}

main();
