
const { Client } = require('pg');

// Connection string taken from .env
const connectionString = "postgresql://postgres.yvjyhbzmnlttplszqfzo:Azli1970%21123@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres";

const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
});

async function main() {
    console.log('Connecting to database...');
    try {
        await client.connect();
        console.log('✅ Connected!');

        const values = [
            'IN_REVIEW',
            'PAYOUT_PROCESSING',
            'PAYOUT_HOLD',
            'PAID_OUT',
            'PAYOUT_FAILED',
            'PAYOUT_FAILED_MANUAL'
        ];

        for (const val of values) {
            console.log(`Adding enum value: ${val}`);
            try {
                await client.query(`ALTER TYPE "JobStatus" ADD VALUE IF NOT EXISTS '${val}'`);
                console.log(`  ✅ Added ${val}`);
            } catch (err) {
                console.log(`  ⚠️  Error adding ${val}: ${err.message}`);
            }
        }

        console.log('🎉 Fix Applied!');
    } catch (err) {
        console.error('❌ Connection Failed:', err);
    } finally {
        await client.end();
    }
}

main();
