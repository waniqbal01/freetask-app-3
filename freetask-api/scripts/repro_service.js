const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    try {
        // 1. Find a freelancer
        const freelancer = await prisma.user.findFirst({
            where: { role: 'FREELANCER' },
        });

        if (!freelancer) {
            console.log('No freelancer found to create service.');
            return;
        }
        console.log(`Using freelancer: ${freelancer.email} (ID: ${freelancer.id})`);

        // 2. Create a service directly using Prisma (simulating ServiceService.create)
        const service = await prisma.service.create({
            data: {
                title: 'Test Pending Service ' + Date.now(),
                description: 'This is a test service to check pending status.',
                price: 100.00,
                category: 'Digital & Tech',
                freelancerId: freelancer.id,
                approvalStatus: 'PENDING', // Explicitly set to PENDING
            },
        });

        console.log(`Created Service ID: ${service.id}, Status: ${service.approvalStatus}`);

        // 3. Verify it exists in Pending Query
        const pendingServices = await prisma.service.findMany({
            where: { approvalStatus: 'PENDING' },
        });

        console.log(`Number of Pending Services found: ${pendingServices.length}`);
        pendingServices.forEach(s => console.log(`- [${s.id}] ${s.title} (${s.approvalStatus})`));

    } catch (e) {
        console.error(e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
