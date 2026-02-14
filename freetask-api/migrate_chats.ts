import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Starting migration of messages to Conversations...');

    const jobsWithMessages = await prisma.job.findMany({
        where: {
            messages: { some: {} }
        },
        include: { messages: true }
    });

    console.log(`Found ${jobsWithMessages.length} jobs with messages.`);

    for (const job of jobsWithMessages) {
        const clientId = job.clientId;
        const freelancerId = job.freelancerId;

        // Find existing conversation between these two
        // Since querying many-to-many is hard, fetch conversations for client and filter
        const clientConversations = await prisma.conversation.findMany({
            where: {
                participants: { some: { id: clientId } }
            },
            include: {
                participants: true
            }
        });

        let conversation = clientConversations.find(c =>
            c.participants.some(p => p.id === freelancerId)
        );

        if (!conversation) {
            console.log(`Creating new conversation for Client ${clientId} and Freelancer ${freelancerId}`);
            conversation = await prisma.conversation.create({
                data: {
                    participants: {
                        connect: [
                            { id: clientId },
                            { id: freelancerId }
                        ]
                    }
                },
                include: { participants: true }
            });
        } else {
            console.log(`Using existing conversation ${conversation.id} for Client ${clientId} and Freelancer ${freelancerId}`);
        }

        // Update messages
        const updateResult = await prisma.chatMessage.updateMany({
            where: { jobId: job.id },
            data: { conversationId: conversation.id }
        });

        console.log(`Moved ${updateResult.count} messages from Job ${job.id} to Conversation ${conversation.id}`);
    }

    console.log('Migration completed.');
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
