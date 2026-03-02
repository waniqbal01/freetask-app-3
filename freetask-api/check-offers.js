const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
    const offerMessages = await prisma.chatMessage.findMany({
        where: { type: 'offer' },
        select: { id: true, content: true },
        orderBy: { createdAt: 'desc' },
        take: 5
    });
    console.log(JSON.stringify(offerMessages, null, 2));
    await prisma.$disconnect();
}
run();
