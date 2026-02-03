const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, 'freetask-api', '.env');
const backupPath = path.join(__dirname, 'freetask-api', '.env.render-backup');

console.log('📝 Updating .env file for Supabase connection...\n');

// Read current .env
const envContent = fs.readFileSync(envPath, 'utf8');

// Create backup
fs.writeFileSync(backupPath, envContent);
console.log('✅ Created backup: .env.render-backup\n');

// Replace DATABASE_URL
const supabaseUrl = 'postgresql://postgres.yvjyhbzmnlttplszqfzo:Azli1970!123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true';

const updatedContent = envContent.replace(
    /DATABASE_URL=.*/,
    `DATABASE_URL=${supabaseUrl}`
);

// Write updated .env
fs.writeFileSync(envPath, updatedContent);

console.log('✅ Updated DATABASE_URL in .env file\n');
console.log('Old URL: Render PostgreSQL');
console.log('New URL: Supabase PostgreSQL (Transaction pooler)\n');

console.log('═'.repeat(70));
console.log('NEXT STEPS:');
console.log('═'.repeat(70));
console.log('1. Import SQL file to Supabase (follow walkthrough.md)');
console.log('2. Test API connection: cd freetask-api && npm run start:dev');
console.log('3. Verify all endpoints work correctly');
console.log('');
console.log('If you need to revert: Copy .env.render-backup to .env\n');
