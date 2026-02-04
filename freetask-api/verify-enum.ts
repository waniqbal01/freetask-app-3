
import { PrismaClient, JobStatus } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Verifying Enum Update...');

    try {
        // Try to query with the new enum value
        // This previously failed with "invalid input value for enum"
        const count = await prisma.job.count({
            where: {
                status: JobStatus.IN_REVIEW
            }
        });
        console.log(`✅ Success! Verified 'IN_REVIEW' is accepted. Found ${count} jobs.`);

        const count2 = await prisma.job.count({
            where: {
                status: JobStatus.PAYOUT_PROCESSING
            }
        });
        console.log(`✅ Success! Verified 'PAYOUT_PROCESSING' is accepted. Found ${count2} jobs.`);

    } catch (e) {
        console.error('❌ Verification Failed:', e);
        process.exit(1);
    } finally {
        await prisma.$disconnect();
    }
}

main();
