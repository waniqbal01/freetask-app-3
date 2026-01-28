import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    const jobTitle = 'cipta logo';
    console.log(`Searching for job with title containing: "${jobTitle}"...`);

    const jobs = await prisma.job.findMany({
        where: {
            title: {
                contains: jobTitle,
                mode: 'insensitive',
            },
        },
        include: {
            client: true,
            service: true,
        }
    });

    if (jobs.length === 0) {
        console.log('No jobs found.');
    } else {
        jobs.forEach(job => {
            console.log('--------------------------------------------------');
            console.log(`Job ID: ${job.id}`);
            console.log(`Title: ${job.title}`);
            console.log(`Status: ${job.status}`);
            console.log(`Amount: ${job.amount}`);
            console.log(`Client: ${job.client.email}`);
            console.log('--------------------------------------------------');
        });
    }
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
