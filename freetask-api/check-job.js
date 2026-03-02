const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
    const job = await prisma.job.findUnique({ where: { id: 5 } });
    console.log('Job 5 STATUS:', job);
    await prisma.$disconnect();
}
run();
