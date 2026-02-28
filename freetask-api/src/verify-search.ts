import { PrismaClient } from '@prisma/client';

async function verifySearch() {
    const prisma = new PrismaClient();
    const queries = [
        'Logo', // Should match service title
        'Wan',  // Should match freelancer name
        'Professional', // Should match category (encoded in DB as &amp; Professional)
    ];

    console.log('--- Verifying Search Functionality ---');

    for (const q of queries) {
        console.log(`\nSearching for: "${q}"`);
        const freelancers = await prisma.user.findMany({
            where: {
                role: 'FREELANCER',
                isAvailable: true,
                OR: [
                    { name: { contains: q, mode: 'insensitive' } },
                    { bio: { contains: q, mode: 'insensitive' } },
                    {
                        services: {
                            some: {
                                OR: [
                                    { title: { contains: q, mode: 'insensitive' } },
                                    { category: { contains: q, mode: 'insensitive' } },
                                ],
                                approvalStatus: 'APPROVED',
                                isActive: true,
                            },
                        },
                    },
                ],
            },
            select: {
                name: true,
                bio: true,
                services: {
                    where: { approvalStatus: 'APPROVED', isActive: true },
                    select: { title: true, category: true },
                },
            },
        });

        console.log(`Found ${freelancers.length} freelancers.`);
        freelancers.forEach(f => {
            console.log(`- ${f.name} (Bio: ${f.bio?.substring(0, 30)}...)`);
            f.services.forEach(s => {
                console.log(`  * Service: ${s.title} [${s.category}]`);
            });
        });
    }

    await prisma.$disconnect();
}

verifySearch().catch(console.error);
