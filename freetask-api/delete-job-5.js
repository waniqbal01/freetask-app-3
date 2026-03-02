const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
    const jobId = 5;
    console.log('Manually deleting Job', jobId);

    // delete offer message
    const offerMessages = await prisma.chatMessage.findMany({
        where: { type: 'offer' },
    });

    for (const msg of offerMessages) {
        if (!msg.content) continue;
        try {
            const data = JSON.parse(msg.content);
            if (data.offerJobId == jobId) {
                console.log('Deleting associated chat message', msg.id);
                await prisma.chatMessage.delete({ where: { id: msg.id } });
            }
        } catch (e) { }
    }

    // delete job
    await prisma.job.delete({ where: { id: jobId } });
    console.log('Job 5 deleted successfully.');

    await prisma.$disconnect();
}
run();
