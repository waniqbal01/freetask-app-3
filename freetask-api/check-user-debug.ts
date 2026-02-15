import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkUser() {
    const email = 'waniqbal@gmail.com';
    console.log(`Checking user: ${email}...`);

    const user = await prisma.user.findUnique({
        where: { email },
        include: { sessions: true }
    });

    if (!user) {
        console.log('User not found!');
        return;
    }

    console.log('User found:');
    console.log(JSON.stringify(user, null, 2));

    // Check recent sessions
    console.log('\nSessions:');
    user.sessions.slice(0, 5).forEach(s => {
        console.log(`- ID: ${s.id}, Revoked: ${s.revoked}, Expires: ${s.refreshTokenExpiresAt}`);
    });
}

checkUser()
    .catch(e => console.error(e))
    .finally(async () => await prisma.$disconnect());
