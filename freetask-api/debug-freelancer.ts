import axios from 'axios';

const BASE_URL = 'http://127.0.0.1:4002';
const EMAIL = `freelancer_test_${Date.now()}@example.com`;
const PASSWORD = 'Password123!';

async function run() {
    try {
        // 1. Register
        console.log(`Registering ${EMAIL}...`);
        try {
            const registerResponse = await axios.post(`${BASE_URL}/auth/register`, {
                email: EMAIL,
                password: PASSWORD,
                name: 'Test Freelancer',
                role: 'FREELANCER'
            });

            const token = registerResponse.data.accessToken;
            const user = registerResponse.data.user;
            console.log('Registered User:', user);
            console.log('Role from Register:', user.role);

            // 2. Fetch Jobs (Freelancer Filter)
            console.log('Fetching jobs with filter=freelancer...');
            const jobsResponse = await axios.get(`${BASE_URL}/jobs`, {
                params: { filter: 'freelancer' },
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log('Jobs Response Status:', jobsResponse.status);
            console.log('Jobs Count:', jobsResponse.data.length);

            // 3. Fetch Jobs (Client Filter)
            console.log('Fetching jobs with filter=client...');
            const clientJobsResponse = await axios.get(`${BASE_URL}/jobs`, {
                params: { filter: 'client' },
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log('Client Jobs Count:', clientJobsResponse.data.length);

            // 4. Fetch Auth Me
            console.log('Fetching /auth/me...');
            const meResponse = await axios.get(`${BASE_URL}/auth/me`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log('Me Response Role:', meResponse.data.role);

        } catch (e: any) {
            if (e.response) {
                console.error('API Error Status:', e.response.status);
                console.error('API Error Data:', JSON.stringify(e.response.data, null, 2));
            } else {
                console.error('Network/Script Error:', e.message);
            }
        }


    } catch (error: any) {
        console.error('Unexpected Error:', error);
    }
}

run();
