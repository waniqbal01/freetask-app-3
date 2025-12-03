import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    const email = 'wan03@gmail.com';

    const user = await prisma.user.findUnique({
        where: { email }
    });

    if (!user) {
        console.log(`User ${email} not found`);
        return;
    }

    await prisma.user.delete({
        where: { email }
    });

    console.log(`✅ User ${email} (ID: ${user.id}) deleted successfully`);
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
