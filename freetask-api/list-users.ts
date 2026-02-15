import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    try {
        const users = await prisma.user.findMany({
            select: { id: true, email: true, role: true },
        });
        console.log('Users found:', users.length);
        users.forEach((u) => console.log(`${u.id}: ${u.email} (${u.role})`));
    } catch (e: any) {
        console.error('Error listing users:', e.message);
    } finally {
        await prisma.$disconnect();
    }
}

main();
