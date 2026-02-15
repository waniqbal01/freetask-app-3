import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkUser() {
    const email = 'waniqbal@gmail.com';
    console.log(`CHECKING USER: ${email}`);

    const user = await prisma.user.findUnique({
        where: { email },
        include: { sessions: true }
    });

    if (!user) {
        console.log('USER NOT FOUND');
        return;
    }

    console.log(`ID: ${user.id}`);
    console.log(`ROLE: ${user.role}`);
    console.log(`SESSIONS COUNT: ${user.sessions.length}`);

    // Last session
    if (user.sessions.length > 0) {
        const last = user.sessions[user.sessions.length - 1];
        console.log(`LAST SESSION ID: ${last.id}`);
        console.log(`LAST SESSION REVOKED: ${last.revoked}`);
        console.log(`LAST SESSION EXPIRES: ${last.refreshTokenExpiresAt.toISOString()}`);
    }
}

checkUser()
    .catch(e => console.error(e))
    .finally(async () => await prisma.$disconnect());
