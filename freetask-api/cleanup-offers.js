const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
    const offerMessages = await prisma.chatMessage.findMany({
        where: { type: "offer" }
    });

    let deletedCount = 0;
    for (const msg of offerMessages) {
        try {
            if (!msg.content) continue;
            const data = JSON.parse(msg.content);
            const jobId = data.offerJobId;
            if (jobId) {
                // check if job still exists
                const job = await prisma.job.findUnique({ where: { id: jobId } });
                if (!job) {
                    console.log(`Deleting orphan offer message ${msg.id} for missing job ${jobId}`);
                    await prisma.chatMessage.delete({ where: { id: msg.id } });
                    deletedCount++;
                }
            }
        } catch (e) {
            console.error(e);
        }
    }
    console.log(`Deleted ${deletedCount} stranded offer messages.`);
    await prisma.$disconnect();
}
run();
