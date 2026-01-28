// Simple test script untuk verify Billplz configuration
// Usage: node test-billplz-config.js

require('dotenv').config();

console.log('===========================================');
console.log('  BILLPLZ CONFIGURATION CHECK');
console.log('===========================================\n');

const config = {
    'BILLPLZ_API_KEY': process.env.BILLPLZ_API_KEY,
    'BILLPLZ_COLLECTION_ID': process.env.BILLPLZ_COLLECTION_ID,
    'BILLPLZ_X_SIGNATURE_KEY': process.env.BILLPLZ_X_SIGNATURE_KEY,
    'BILLPLZ_SANDBOX': process.env.BILLPLZ_SANDBOX,
    'API_URL': process.env.API_URL,
    'APP_URL': process.env.APP_URL,
};

let hasErrors = false;

Object.entries(config).forEach(([key, value]) => {
    const isSet = value && value.trim() !== '';
    const status = isSet ? '✅ Set' : '❌ Not Set';
    console.log(`${key.padEnd(30)} ${status}`);

    if (!isSet && key.startsWith('BILLPLZ_')) {
        hasErrors = true;
    }
});

console.log('\n===========================================');

if (hasErrors) {
    console.log('❌ ERROR: Billplz credentials are missing!');
    console.log('\nPlease follow these steps:');
    console.log('1. Copy .env.example to .env');
    console.log('2. Get credentials from https://www.billplz-sandbox.com');
    console.log('3. Update .env file with your credentials');
    console.log('4. Run this script again\n');
    console.log('See BILLPLZ_SETUP.md for detailed instructions.');
    process.exit(1);
} else {
    console.log('✅ All Billplz credentials are configured!');

    const isSandbox = process.env.BILLPLZ_SANDBOX === 'true';
    console.log(`\nMode: ${isSandbox ? '🧪 SANDBOX (Testing)' : '🚀 PRODUCTION'}`);

    if (!isSandbox) {
        console.log('\n⚠️  WARNING: You are using PRODUCTION credentials!');
        console.log('Real payments will be processed. Use BILLPLZ_SANDBOX=true for testing.');
    }

    console.log('\nNext steps:');
    console.log('1. Start backend: npm run start:dev');
    console.log('2. Check logs for Billplz initialization');
    console.log('3. Test payment creation from Flutter app');
}

console.log('===========================================\n');
