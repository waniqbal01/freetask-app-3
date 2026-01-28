require('dotenv').config();
const axios = require('axios');

async function testBillplz() {
    const API_KEY = process.env.BILLPLZ_API_KEY;
    const COLLECTION_ID = process.env.BILLPLZ_COLLECTION_ID;
    const SANDBOX = process.env.BILLPLZ_SANDBOX === 'true';

    console.log('Testing Billplz Direct...');
    console.log(`Sandbox: ${SANDBOX}`);
    console.log(`Collection ID: ${COLLECTION_ID}`);
    // Obfuscate API Key
    console.log(`API Key: ${API_KEY ? API_KEY.substring(0, 4) + '...' : 'MISSING'}`);

    const baseURL = SANDBOX
        ? 'https://www.billplz-sandbox.com/api/v3'
        : 'https://www.billplz.com/api/v3';

    try {
        const payload = {
            collection_id: COLLECTION_ID,
            email: 'client@example.com', // Suspicious email for Prod
            name: 'Test Client',
            amount: 1000, // 10.00 MYR
            description: 'Direct Test Payment',
            callback_url: 'http://localhost:3000/callback',
            redirect_url: 'http://localhost:3000/redirect'
        };

        console.log(`Sending Payload to ${baseURL}/bills:`, payload);

        const checkAuth = await axios.get(`${baseURL}/collections/${COLLECTION_ID}`, {
            auth: { username: API_KEY, password: '' }
        });
        console.log('Collection Check: ', checkAuth.status === 200 ? 'OK' : checkAuth.status);


        const response = await axios.post(`${baseURL}/bills`, payload, {
            auth: {
                username: API_KEY,
                password: '',
            },
        });

        console.log('✅ Success! Bill ID:', response.data.id);
        console.log('URL:', response.data.url);

    } catch (error) {
        console.error('❌ Failed!');
        if (error.response) {
            console.error(`Status: ${error.response.status}`);
            console.error('Body:', JSON.stringify(error.response.data, null, 2));
        } else {
            console.error(error.message);
        }
    }
}

testBillplz();
