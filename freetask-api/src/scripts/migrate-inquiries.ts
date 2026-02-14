import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Starting migration of Inquiries to Conversations...');

    // 1. Fetch all Inquiries (Jobs with status INQUIRY)
    // We also want to fetch jobs connected to messages that have no conversationId
    // This covers both "pure" inquiries and active jobs with old chats.

    // Strategy:
    // A. Process "Inquiry" jobs to ensure they have conversations.
    // B. Process ALL messages with null conversationId to link them.

    // Step A: Inquiries
    const inquiries = await prisma.job.findMany({
        where: { status: 'INQUIRY' },
        include: { messages: true },
    });

    console.log(`Found ${inquiries.length} inquiry jobs.`);

    for (const inquiry of inquiries) {
        if (!inquiry.clientId || !inquiry.freelancerId) {
            console.warn(`Skipping inquiry ${inquiry.id}: Missing client or freelancer ID`);
            continue;
        }

        try {
            const conversation = await getOrCreateConversation(inquiry.clientId, inquiry.freelancerId);

            // If the inquiry has a description but no messages, create an initial message
            // This preserves the context of the inquiry if it wasn't already a message
            if (inquiry.description && inquiry.messages.length === 0) {
                // Check if we already created a message with this exact content recently to avoid dups on re-run
                const existing = await prisma.chatMessage.findFirst({
                    where: {
                        conversationId: conversation.id,
                        content: inquiry.description,
                        senderId: inquiry.clientId
                    }
                });

                if (!existing) {
                    console.log(`Creating initial message from description for Inquiry ${inquiry.id}`);
                    await prisma.chatMessage.create({
                        data: {
                            content: inquiry.description,
                            senderId: inquiry.clientId,
                            conversationId: conversation.id,
                            status: 'SENT',
                            createdAt: inquiry.createdAt // Preserve timestamp
                        }
                    });
                }
            }
        } catch (error) {
            console.error(`Failed to process inquiry ${inquiry.id}:`, error);
        }
    }

    // Step B: Migrate Orphans (Messages without Conversation)
    // This is the heavy lifting: find messages without conversationId, link them to a conversation.
    // We can group by jobId to bulk process.

    // Get all unique Job IDs from messages with no conversationId
    const messagesWithNoConv = await prisma.chatMessage.findMany({
        where: {
            conversationId: null,
            jobId: { not: null }
        },
        select: { jobId: true },
        distinct: ['jobId']
    });

    console.log(`Found ${messagesWithNoConv.length} jobs with non-migrated messages.`);

    for (const item of messagesWithNoConv) {
        if (!item.jobId) continue;

        const job = await prisma.job.findUnique({
            where: { id: item.jobId },
            select: { id: true, clientId: true, freelancerId: true }
        });

        if (!job) {
            console.warn(`Job ${item.jobId} not found for messages. Skipping.`);
            continue;
        }

        try {
            const conversation = await getOrCreateConversation(job.clientId, job.freelancerId);

            // Update all messages for this job
            const result = await prisma.chatMessage.updateMany({
                where: {
                    jobId: job.id,
                    conversationId: null
                },
                data: {
                    conversationId: conversation.id
                }
            });
            console.log(`Migrated ${result.count} messages for Job ${job.id} to Conversation ${conversation.id}`);
        } catch (error) {
            console.error(`Error migrating messages for job ${job.id}:`, error);
        }
    }

    console.log('Migration complete.');
}

async function getOrCreateConversation(clientId: number, freelancerId: number) {
    // Find existing conversation between these two
    let conversation = await prisma.conversation.findFirst({
        where: {
            AND: [
                { participants: { some: { id: clientId } } },
                { participants: { some: { id: freelancerId } } },
            ],
        },
    });

    if (!conversation) {
        console.log(`Creating new conversation: Client ${clientId} <-> Freelancer ${freelancerId}`);
        conversation = await prisma.conversation.create({
            data: {
                participants: {
                    connect: [{ id: clientId }, { id: freelancerId }],
                },
            },
        });
    }

    return conversation;
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
