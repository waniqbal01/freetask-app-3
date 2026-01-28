
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

async function main() {
    const prisma = new PrismaClient();
    try {
        const log = await prisma.adminLog.findFirst({
            where: { action: 'RELEASE_PAYOUT_HOLD' },
            orderBy: { createdAt: 'desc' }
        });

        if (log && log.details) {
            console.log('--- ERROR DETAILS ---');
            console.log(JSON.stringify(log.details, null, 2));
        } else {
            console.log('No log found');
        }
    } catch (e) {
        console.error(e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
