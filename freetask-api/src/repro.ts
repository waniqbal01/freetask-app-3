import { PrismaClient, UserRole } from '@prisma/client';
import * as dotenv from 'dotenv';

dotenv.config();

const dbUrl = process.env.DATABASE_URL;
console.log('DATABASE_URL:', dbUrl?.replace(/:([^:@]+)@/, ':****@')); // Mask password


const prisma = new PrismaClient({
    log: ['query', 'info', 'warn', 'error'],
});

async function main() {
    console.log('Connecting to database...');
    await prisma.$connect();
    console.log('Connected!');

    const userId = 1; // Try with user 1
    const role: UserRole = UserRole.FREELANCER; // Explicit type check

    console.log(`Running findMany query for userId ${userId}...`);

    try {
        // 1. Fetch Jobs
        const jobs = await prisma.job.findMany({
            where:
                (role as any) === UserRole.ADMIN
                    ? {}
                    : {
                        OR: [{ clientId: userId }, { freelancerId: userId }],
                    },
            include: {
                client: {
                    select: { id: true },
                },
                // freelancer: {
                //     select: { id: true, name: true },
                // },
            },
            orderBy: { updatedAt: 'desc' },
            take: 20,
            skip: 0,
        });

        console.log(`Found ${jobs.length} jobs. Fetching last messages...`);

        // 2. Fetch Last Message for each job
        const results = await Promise.all(jobs.map(async (job) => {
            const lastMsg = await prisma.chatMessage.findFirst({
                where: { jobId: job.id },
                orderBy: { createdAt: 'desc' },
            });
            return { job: job.id, lastMsg: lastMsg?.content };
        }));

        console.log('Results:', results);
    } catch (error) {
        console.error('Error running query:', error);
    } finally {
        await prisma.$disconnect();
    }
}

main();
