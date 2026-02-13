
import axios from 'axios';

const API_URL = 'http://localhost:4000';

function generateRandomEmail(prefix: string) {
    const random = Math.floor(Math.random() * 100000);
    return `${prefix}${random}@example.com`;
}

async function register(email: string, role: 'CLIENT' | 'FREELANCER') {
    try {
        console.log(`Registering ${role}: ${email}`);
        await axios.post(`${API_URL}/auth/register`, {
            email,
            password: 'Password123!',
            name: `${role} Test User`,
            role
        });
        // Login to get token
        const res = await axios.post(`${API_URL}/auth/login`, {
            email,
            password: 'Password123!'
        });
        return res.data.accessToken;
    } catch (error) {
        console.error(`Registration/Login failed for ${email}:`, (error as any).response?.data || (error as any).message);
        throw error;
    }
}

async function run() {
    try {
        // 1. Setup Freelancer
        const freelancerEmail = generateRandomEmail('freelancer');
        const freelancerToken = await register(freelancerEmail, 'FREELANCER');
        console.log('Freelancer registered and logged in.');

        // 2. Create Service
        console.log('Creating Service...');
        const serviceRes = await axios.post(`${API_URL}/services`, {
            title: 'Test Service ' + Date.now(),
            description: 'A test service for job flow audit.',
            price: 50,
            category: 'Testing'
        }, {
            headers: { Authorization: `Bearer ${freelancerToken}` }
        });
        const serviceId = serviceRes.data.id;
        console.log(`Service Created: ID ${serviceId}`);

        // 3. Setup Client
        const clientEmail = generateRandomEmail('client');
        const clientToken = await register(clientEmail, 'CLIENT');
        console.log('Client registered and logged in.');

        // 4. Create Job
        console.log('Creating Job...');
        const jobRes = await axios.post(`${API_URL}/jobs`, {
            serviceId: serviceId,
            description: 'Test Job Auto-created',
            amount: 50
        }, {
            headers: { Authorization: `Bearer ${clientToken}` }
        });
        const jobId = jobRes.data.id;
        console.log(`Job Created: ID ${jobId}, Status: ${jobRes.data.status}`);

        // 5. Freelancer Accepts Job
        console.log('Freelancer accepting Job...');
        const acceptRes = await axios.patch(`${API_URL}/jobs/${jobId}/accept`, {}, {
            headers: { Authorization: `Bearer ${freelancerToken}` }
        });
        console.log(`Job Accepted: Status: ${acceptRes.data.status}`);

        // 6. Verify Status
        if (acceptRes.data.status !== 'AWAITING_PAYMENT') {
            console.error('Expected status AWAITING_PAYMENT, got', acceptRes.data.status);
            process.exit(1);
        } else {
            console.log('SUCCESS: Job flow to AWAITING_PAYMENT verified.');
        }

    } catch (error) {
        console.error('Test Failed:', (error as any).response?.data || (error as any).message);
        process.exit(1);
    }
}

run();
