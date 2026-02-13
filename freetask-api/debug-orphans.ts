
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Fetching all job IDs...');
    const jobs = await prisma.job.findMany({
        select: { id: true }
    });
    console.log(`Found ${jobs.length} jobs. Checking each one...`);

    for (const job of jobs) {
        try {
            // 1. Test Client Include
            try {
                await prisma.job.findUnique({
                    where: { id: job.id },
                    include: { client: { select: { id: true } } }
                });
                console.log(`Job ${job.id}: Client include OK`);
            } catch (e) {
                console.error(`Job ${job.id}: CRASHED on CLIENT include`);
            }

            // 2. Test Freelancer Include
            try {
                await prisma.job.findUnique({
                    where: { id: job.id },
                    include: { freelancer: { select: { id: true } } }
                });
                console.log(`Job ${job.id}: Freelancer include OK`);
            } catch (e) {
                console.error(`Job ${job.id}: CRASHED on FREELANCER include`);
            }

            // 3. Test Messages Include
            try {
                await prisma.job.findUnique({
                    where: { id: job.id },
                    include: { messages: { take: 1 } }
                });
                console.log(`Job ${job.id}: Messages include OK`);
            } catch (e) {
                console.error(`Job ${job.id}: CRASHED on MESSAGES include`);
            }
            // process.stdout.write('.'); // progress indicator
        } catch (error) {
            console.error(`\nCRASH DETECTED on Job ID: ${job.id}`);
            // Investigate why
            const rawJob = await prisma.job.findUnique({ where: { id: job.id } });
            console.log('Raw Job Data:', rawJob);

            if (rawJob) {
                const client = await prisma.user.findUnique({ where: { id: rawJob.clientId } });
                const freelancer = await prisma.user.findUnique({ where: { id: rawJob.freelancerId } });

                if (client) console.log(`Client ${client.id} found.`);
                else console.error(`MISSING CLIENT! User ID ${rawJob.clientId} not found.`);

                if (freelancer) console.log(`Freelancer ${freelancer.id} found.`);
                else console.error(`MISSING FREELANCER! User ID ${rawJob.freelancerId} not found.`);

                const service = await prisma.service.findUnique({ where: { id: rawJob.serviceId } });
                if (service) console.log(`Service ${service.id} found.`);
                else console.error(`MISSING SERVICE! Service ID ${rawJob.serviceId} not found.`);
            }
        }
    }
    console.log('\nDone.');
    await prisma.$disconnect();
}

main();
