
const axios = require('axios');
const fs = require('fs');
const path = require('path');

async function main() {
    const envPath = path.resolve(__dirname, '.env');
    console.log('Reading .env from:', envPath);

    if (!fs.existsSync(envPath)) {
        console.error('❌ .env file not found!');
        process.exit(1);
    }

    const envContent = fs.readFileSync(envPath, 'utf8');
    const envConfig = {};
    envContent.split('\n').forEach(line => {
        const [key, value] = line.split('=');
        if (key && value) {
            envConfig[key.trim()] = value.trim();
        }
    });

    const apiKey = envConfig['BILLPLZ_API_KEY'];
    const isSandbox = envConfig['BILLPLZ_SANDBOX'] === 'true';

    console.log(`API Key: ${apiKey ? 'Starts with ' + apiKey.substring(0, 5) : 'MISSING'}`);
    console.log(`Sandbox: ${isSandbox}`);

    if (!apiKey) {
        console.error('❌ Missing BILLPLZ_API_KEY');
        process.exit(1);
    }

    const baseURL = isSandbox
        ? 'https://www.billplz-sandbox.com'
        : 'https://www.billplz.com';

    console.log(`Target URL: ${baseURL}`);

    const client = axios.create({
        baseURL,
        auth: {
            username: apiKey,
            password: '',
        },
        timeout: 10000,
    });

    const endpoints = [
        '/api/v3/collections', // GET request to verify connectivity and Auth
        '/api/v4/payouts',
        '/api/v4/payment_orders',
        '/api/v4/mass_payment_instruction_collections',
    ];

    for (const endpoint of endpoints) {
        console.log(`\nTesting Endpoint: ${endpoint}`);
        const method = endpoint.includes('collections') && endpoint.includes('v3') ? 'get' : 'post';

        try {
            await client[method](endpoint, method === 'post' ? {
                title: 'Test',
                currency: 'MYR',
                amount: 100,
                bank_code: 'MBB',
                bank_account_number: '111111111111',
                account_holder_name: 'Test',
                reference_id: `TV-${Date.now()}`
            } : undefined);

            console.log('✅ Endpoint VALID (Success/200)');

        } catch (error) {
            if (error.response) {
                console.log(`Response: ${error.response.status} ${error.response.statusText}`);
                if (error.response.status !== 404) {
                    console.log('✅ Endpoint EXISTED (Not 404). This might be the correct one.');
                    // console.log(JSON.stringify(error.response.data, null, 2));
                } else {
                    console.log('❌ Endpoint NOT FOUND');
                }
            } else {
                console.log('❌ Error:', error.message);
            }
        }
    }
}

main();
