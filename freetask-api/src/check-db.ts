import { PrismaClient } from '@prisma/client';

async function checkDb() {
    const prisma = new PrismaClient();

    const freelancers = await prisma.user.findMany({
        where: { role: 'FREELANCER' },
        select: {
            id: true,
            name: true,
            isAvailable: true,
            services: {
                select: {
                    id: true,
                    title: true,
                    category: true,
                    approvalStatus: true,
                    isActive: true
                }
            }
        }
    });

    console.log('--- Database Check ---');
    console.log(`Total Freelancers: ${freelancers.length}`);
    freelancers.forEach(f => {
        console.log(`\nFreelancer: ${f.name} (Available: ${f.isAvailable})`);
        console.log(`Services (${f.services.length}):`);
        f.services.forEach(s => {
            console.log(`  - [${s.approvalStatus}] [Active: ${s.isActive}] ${s.title} (${s.category})`);
        });
    });

    await prisma.$disconnect();
}

checkDb().catch(console.error);
