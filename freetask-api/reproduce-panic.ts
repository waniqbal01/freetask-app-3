
import { PrismaClient, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Connecting to database...');
    try {
        // Mimic the query from ChatsService.listThreads
        // we need a valid userId to tests, or we can just query all if we pass ADMIN role logic
        // The service logic:
        /*
        where:
            role === UserRole.ADMIN
              ? {}
              : {
                OR: [{ clientId: userId }, { freelancerId: userId }],
              },
        */

        // Let's try to fetch ALL jobs first to see if any of them trigger the panic
        console.log('Attempting to fetch all jobs with includes...');

        const jobs = await prisma.job.findMany({
            include: {
                client: {
                    select: { id: true, name: true },
                },
                freelancer: {
                    select: { id: true, name: true },
                },
                messages: {
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                },
            },
            orderBy: { updatedAt: 'desc' },
            take: 50,
        });

        console.log(`Successfully fetched ${jobs.length} jobs.`);

        // Check for potential orphans manually
        for (const job of jobs) {
            if (!job.client) console.error(`Job ${job.id} has no client!`);
            if (!job.freelancer) console.error(`Job ${job.id} has no freelancer!`);
        }

    } catch (error) {
        console.error('CRASHED!');
        console.error(error);
    } finally {
        await prisma.$disconnect();
    }
}

main();
