const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Load .env manually
const envPath = path.resolve(__dirname, '.env');
const envConfig = {};
if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf-8');
    envContent.split('\n').forEach(line => {
        const parts = line.split('=');
        if (parts.length >= 2) {
            const key = parts[0].trim();
            const value = parts.slice(1).join('=').trim();
            if (key && !key.startsWith('#')) {
                envConfig[key] = value;
            }
        }
    });
}

const API_KEY = envConfig.BILLPLZ_API_KEY;
const COLLECTION_ID = envConfig.BILLPLZ_COLLECTION_ID;
const IS_SANDBOX = envConfig.BILLPLZ_SANDBOX === 'true';

console.log('--- Billplz Configuration Check ---');
console.log(`Sandbox Mode: ${IS_SANDBOX}`);
console.log(`API Key: ${API_KEY ? 'Set (starts with ' + API_KEY.substring(0, 4) + ')' : 'NOT SET'}`);
console.log(`Collection ID: ${COLLECTION_ID}`);

if (!API_KEY || !COLLECTION_ID) {
    console.error('❌ Missing credentials in .env');
    process.exit(1);
}

const baseURL = IS_SANDBOX
    ? 'https://www.billplz-sandbox.com/api/v3'
    : 'https://www.billplz.com/api/v3';

const client = axios.create({
    baseURL,
    auth: {
        username: API_KEY,
        password: ''
    }
});

async function testConnection() {
    try {
        console.log(`\nTesting connection to ${baseURL}...`);

        // 1. Get Collection Details (to verify Key and Collection ID)
        console.log(`Checking Collection ${COLLECTION_ID}...`);
        const response = await client.get(`/collections/${COLLECTION_ID}`);

        console.log('✅ Connection Successful!');
        console.log(`Collection Found: ${response.data.title} (ID: ${response.data.id})`);

        // 2. Try to create a dummy bill (optional, but good to verify creation permission)
        // We won't actually do this to avoid spam, but getting the collection proves auth works.

    } catch (error) {
        console.error('\n❌ Connection Failed!');
        if (error.response) {
            console.error(`Status: ${error.response.status} ${error.response.statusText}`);
            console.error('Response Data:', JSON.stringify(error.response.data, null, 2));

            if (error.response.status === 401) {
                console.error('👉 Cause: Invalid API Key');
            } else if (error.response.status === 404) {
                console.error('👉 Cause: Collection ID not found (or wrong environment - Sandbox vs Production)');
            }
        } else {
            console.error('Error:', error.message);
        }
    }
}

testConnection();
