const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    try {
        const counts = await prisma.service.groupBy({
            by: ['approvalStatus'],
            _count: {
                _all: true,
            },
        });
        console.log('COUNTS:');
        console.log(JSON.stringify(counts, null, 2));

        const pendingServices = await prisma.service.findMany({
            where: { approvalStatus: 'PENDING' },
            take: 5,
        });
        console.log('PENDING SERVICES:');
        console.log(JSON.stringify(pendingServices, null, 2));

    } catch (e) {
        console.error(e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
