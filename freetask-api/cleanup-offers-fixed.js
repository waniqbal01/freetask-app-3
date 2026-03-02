const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
    const offerMessages = await prisma.chatMessage.findMany({
        where: { type: 'offer' },
    });

    let deletedCount = 0;
    for (const msg of offerMessages) {
        if (!msg.content) continue;
        try {
            const data = JSON.parse(msg.content);
            // Clean up ANY offer that points to a non-existent job
            if (data.offerJobId) {
                const job = await prisma.job.findUnique({ where: { id: parseInt(data.offerJobId, 10) } });
                if (!job) {
                    console.log(`Deleting message ${msg.id} - Job ${data.offerJobId} not found`);
                    await prisma.chatMessage.delete({ where: { id: msg.id } });
                    deletedCount++;
                }
            }
        } catch (e) {
            console.error('Error parsing msg', msg.id, e.message);
        }
    }
    console.log(`Deleted ${deletedCount} stranded messages.`);
    await prisma.$disconnect();
}
run();
