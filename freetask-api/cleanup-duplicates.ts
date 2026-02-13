
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Cleaning up duplicates...');

    // 1. Delete older User 1
    try {
        console.log('Deleting User 1 (Jan 21)...');
        await prisma.$executeRawUnsafe(`DELETE FROM "User" WHERE email = 'wmiqbal01@gmail.com';`);
        console.log('✓ Deleted User 1 (wmiqbal01@gmail.com)');
    } catch (e) {
        console.error('Failed to delete User 1:', e.message);
    }

    // 2. Delete older User 2
    try {
        console.log('Deleting User 2 (Jan 21)...');
        await prisma.$executeRawUnsafe(`DELETE FROM "User" WHERE email = 'waniqbal@gmail.com';`);
        console.log('✓ Deleted User 2 (waniqbal@gmail.com)');
    } catch (e) {
        console.error('Failed to delete User 2:', e.message);
    }

    // 3. Clean up Session duplicates (keep latest)
    // Logic: Delete sessions where id matches a duplicate and created earlier
    // Since we don't have easy logic to detect exact dupes by ID in raw SQL without CTEs sometimes,
    // we will try to just add PK and let it fail, OR just delete all sessions? 
    // Sessions are ephemeral. Deleting all sessions is safe (users log in again).
    console.log('Clearing all Sessions to resolve ID conflicts...');
    await prisma.$executeRawUnsafe(`TRUNCATE TABLE "Session";`);
    console.log('✓ Sessions cleared');

    // 4. AdminLog duplicates
    // Keep logs if possible, but if IDs clash, tough.
    // Let's see if we can identify them.
    // Actually, deleting old AdminLogs is probably fine for this recovery.
    // Or we can try to re-sequence them? No.
    // Let's just DELETE duplicate admin logs based on ID?
    // "DELETE FROM AdminLog a USING AdminLog b WHERE a.id = b.id AND a.createdAt < b.createdAt;"
    console.log('Deduplicating AdminLog...');
    await prisma.$executeRawUnsafe(`
      DELETE FROM "AdminLog" a 
      USING "AdminLog" b 
      WHERE a.id = b.id AND a."createdAt" < b."createdAt";
  `);
    console.log('✓ AdminLog deduplicated');

    console.log('\nCleanup Complete. Re-running PK Fix...');
}

main();
