
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Checking for duplicates...');

    // Check Users
    const users = await prisma.user.findMany();
    const userMap = new Map<number, any[]>();
    users.forEach(u => {
        if (!userMap.has(u.id)) userMap.set(u.id, []);
        userMap.get(u.id)?.push(u);
    });

    console.log('\n--- Duplicate Users ---');
    for (const [id, list] of userMap.entries()) {
        if (list.length > 1) {
            console.log(`User ID ${id} has ${list.length} records:`);
            list.forEach(u => console.log(` - Email: ${u.email}, Name: ${u.name}, Created: ${u.createdAt}`));
        }
    }

    console.log('\n--- Done Checking ---');
    await prisma.$disconnect();
}

main();
