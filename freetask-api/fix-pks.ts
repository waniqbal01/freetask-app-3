
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log('Restoring Primary Keys...');

    const tables = [
        'User',
        'Service',
        'PortfolioItem',
        'Job',
        'ChatMessage',
        'Review',
        'Escrow',
        'Session',
        'Notification',
        'DeviceToken',
        'Payment',
        'AdminLog',
        'Withdrawal'
    ];

    for (const table of tables) {
        try {
            console.log(`Adding PK to ${table}...`);
            await prisma.$executeRawUnsafe(`ALTER TABLE "${table}" ADD PRIMARY KEY ("id");`);
            console.log(`✓ PK added to ${table}`);
        } catch (error) {
            if (error.message.includes('multiple primary keys')) {
                console.log(`✓ ${table} already has PK (skipped)`);
            } else if (error.message.includes('already exists')) {
                console.log(`✓ ${table} already has PK (skipped)`);
            } else {
                console.error(`✗ Failed to add PK to ${table}:`, error.message);
            }
        }
    }

    console.log('\nPK Restoration Complete.');
    await prisma.$disconnect();
}

main();
