const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function tryRecover() {
    try {
        // Try querying User table directly - simplest test
        console.log('\n=== User count ===');
        const userCount = await prisma.user.count();
        console.log('Users in DB:', userCount);

        if (userCount > 0) {
            const users = await prisma.user.findMany({ select: { id: true, email: true, role: true, createdAt: true } });
            console.log('Existing users:', JSON.stringify(users, null, 2));
        }

        console.log('\n=== pg_class row count estimates ===');
        const counts = await prisma.$queryRawUnsafe(`
      SELECT c.relname AS table_name, c.reltuples::bigint AS estimated_rows
      FROM pg_class c
      INNER JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r' AND n.nspname = 'public'
      ORDER BY c.relname
    `);
        console.log(JSON.stringify(counts, null, 2));

    } catch (e) {
        console.error('Error:', e.message);
    } finally {
        await prisma.$disconnect();
    }
}

tryRecover();
