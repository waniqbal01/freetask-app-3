import { PrismaClient, UserRole } from '@prisma/client';
import * as dotenv from 'dotenv';

dotenv.config();

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
        const jobs = await prisma.job.findMany({
            where:
                (role as any) === UserRole.ADMIN
                    ? {}
                    : {
                        OR: [{ clientId: userId }, { freelancerId: userId }],
                    },
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
            take: 20,
            skip: 0,
        });
        console.log(`Found ${jobs.length} jobs.`);
    } catch (error) {
        console.error('Error running query:', error);
    } finally {
        await prisma.$disconnect();
    }
}

main();
