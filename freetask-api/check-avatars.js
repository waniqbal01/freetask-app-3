const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function checkFreelancerAvatars() {
    try {
        const users = await prisma.user.findMany({
            where: { role: 'FREELANCER' },
            select: { id: true, name: true, avatarUrl: true }
        });

        console.log('Freelancers in database:');
        console.log(JSON.stringify(users, null, 2));

        const withAvatars = users.filter(u => u.avatarUrl);
        const withoutAvatars = users.filter(u => !u.avatarUrl);

        console.log(`\n✓ Freelancers with avatars: ${withAvatars.length}`);
        console.log(`✗ Freelancers without avatars: ${withoutAvatars.length}`);

    } catch (error) {
        console.error('Error:', error);
    } finally {
        await prisma.$disconnect();
    }
}

checkFreelancerAvatars();
