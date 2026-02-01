
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
    // 1. Load Environment Variables manually
    const envPath = path.resolve(__dirname, '.env');
    if (!fs.existsSync(envPath)) {
        console.error('❌ .env file not found at:', envPath);
        process.exit(1);
    }

    const envConfig = fs.readFileSync(envPath, 'utf8')
        .split('\n')
        .reduce((acc, line) => {
            const [key, value] = line.split('=');
            if (key && value) {
                acc[key.trim()] = value.trim();
            }
            return acc;
        }, {} as Record<string, string>);

    const apiKey = envConfig['BILLPLZ_API_KEY'];
    const isSandbox = envConfig['BILLPLZ_SANDBOX'] === 'true';

    console.log('--- Billplz Payout Verification ---');
    console.log(`Mode: ${isSandbox ? 'SANDBOX' : 'PRODUCTION'}`);
    console.log(`API Key: ${apiKey ? 'Found' : 'Missing'}`);

    if (!apiKey) {
        console.error('❌ Missing BILLPLZ_API_KEY in .env');
        process.exit(1);
    }

    // 2. Configure Axios
    const baseURL = isSandbox
        ? 'https://www.billplz-sandbox.com/api/v4'
        : 'https://www.billplz.com/api/v4';

    const client = axios.create({
        baseURL,
        auth: {
            username: apiKey,
            password: '',
        },
        timeout: 10000,
    });

    // 3. Test Payout Endpoint
    // We will attempt to payout RM 1.00 to a dummy account.
    // In Sandbox, this should work if Mass Payment is enabled.
    // We use a likely invalid bank account number to trigger a specific validation error
    // rather than a full success, OR a success if Sandbox accepts anything.
    
    console.log('\nTesting Payout API Access...');
    
    try {
        const payload = {
            currency: 'MYR',
            amount: 100, // 100 cents = RM1.00
            bank_code: 'MBB', // Maybank
            bank_account_number: '111111111111', // Dummy
            account_holder_name: 'Billplz Test',
            description: 'Verification Test Payout',
            reference_id: `TEST-${Date.now()}`
        };

        console.log(`Sending Payload to ${baseURL}/payouts...`);
        const response = await client.post('/payouts', payload);

        console.log('✅ Payout Request Accepted!');
        console.log('Response:', JSON.stringify(response.data, null, 2));
        console.log('\nResult: Your Billplz account supports Mass Payments/Payouts.');

    } catch (error: any) {
        if (error.response) {
            console.error(`❌ API Error (${error.response.status}):`);
            console.error(JSON.stringify(error.response.data, null, 2));

            if (error.response.status === 401) {
                console.error('\nAnalysis: Authentication Failed. Check your API Key.');
            } else if (error.response.status === 403) {
                console.error('\nAnalysis: Access Forbidden. You might NOT have "Mass Payment" enabled on your Billplz account.');
            } else if (error.response.status === 422) {
                 console.log('\nAnalysis: Validation Error. Using dummy data might have caused this, BUT it means the endpoint is reachable and your account has access!');
                 console.log('✅ Connectivity Verified (Validation Stage Reached).');
            }
        } else {
            console.error('❌ Network/Client Error:', error.message);
        }
    }
}

main().catch(console.error);
