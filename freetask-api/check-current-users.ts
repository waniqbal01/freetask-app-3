
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    const u1 = await prisma.user.findUnique({ where: { id: 1 } });
    const u2 = await prisma.user.findUnique({ where: { id: 2 } });

    console.log('Current User 1:', u1);
    console.log('Current User 2:', u2);

    await prisma.$disconnect();
}

main();
