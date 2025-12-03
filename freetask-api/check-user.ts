import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    const user = await prisma.user.findUnique({
        where: { email: 'wan03@gmail.com' },
        select: { id: true, email: true, name: true, role: true, createdAt: true }
    });

    if (user) {
        console.log('User exists:');
        console.log(JSON.stringify(user, null, 2));
    } else {
        console.log('User does NOT exist');
    }
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
