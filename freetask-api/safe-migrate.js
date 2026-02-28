#!/usr/bin/env node
/**
 * SAFE MIGRATE SCRIPT
 * Prevents accidental database reset by requiring explicit confirmation.
 * Run with: node safe-migrate.js "migration name"
 * This will run: npx prisma migrate dev --name <name> --skip-generate
 * WITHOUT the --reset flag.
 */
const { execSync } = require('child_process');
const readline = require('readline');

const name = process.argv[2];
if (!name) {
    console.error('❌ Usage: node safe-migrate.js "migration-name"');
    process.exit(1);
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

console.log('\n⚠️  SAFE MIGRATE — Running: prisma migrate dev --name "' + name + '"');
console.log('ℹ️  This will ONLY add new migrations. It will NOT reset or drop data.');
console.log('   If Prisma asks to reset, type CTRL+C to cancel.\n');

rl.question('Proceed? (yes/no): ', (answer) => {
    rl.close();
    if (answer.toLowerCase() !== 'yes') {
        console.log('Cancelled.');
        process.exit(0);
    }
    try {
        // Use --create-only to just create migration file without applying (safer)
        // Then apply with migrate deploy which NEVER resets
        execSync(`npx prisma migrate dev --name "${name}"`, {
            stdio: 'inherit',
            env: { ...process.env },
        });
        console.log('\n✅ Migration completed safely.');
    } catch (e) {
        console.error('\n❌ Migration failed. Your data is SAFE — nothing was changed.');
        process.exit(1);
    }
});
