import axios from 'axios';

const BASE_URL = 'http://127.0.0.1:4000'; // Use the main port
const EMAIL = 'waniqbal@gmail.com';
// Assuming password is the same or we need to reset/login. 
// Can we login with this email? If not, we register a new one.
// The user said they logged in as waniqbal@gmail.com
const PASSWORD = 'Password123!';

async function run() {
    try {
        console.log(`Logging in as ${EMAIL}...`);
        let token;
        try {
            const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
                email: EMAIL,
                password: PASSWORD
            });
            token = loginResponse.data.accessToken;
            console.log('Login successful. Token obtained.');
        } catch (e) {
            console.log('Login failed (maybe user exists with diff password or manual login needed).');
            console.log('Registering new freelancer for test...');
            const newEmail = `freelancer_srv_${Date.now()}@example.com`;
            const regResponse = await axios.post(`${BASE_URL}/auth/register`, {
                email: newEmail,
                password: PASSWORD,
                name: 'Freelancer Srv',
                role: 'FREELANCER'
            });
            token = regResponse.data.accessToken;
            console.log(`Registered ${newEmail}. Token obtained.`);
        }

        // Test /services/list/my
        console.log('Testing GET /services/list/my ...');
        try {
            const response = await axios.get(`${BASE_URL}/services/list/my`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log('Response Status:', response.status);
            console.log('Services Count:', response.data.length);
        } catch (e: any) {
            if (e.response) {
                console.error('API Error Status:', e.response.status);
                console.error('API Error Data:', JSON.stringify(e.response.data, null, 2));
            } else {
                console.error('Network Error:', e.message);
            }
        }

        // Test /notifications/unread-count
        console.log('Testing GET /notifications/unread-count ...');
        try {
            const notifResponse = await axios.get(`${BASE_URL}/notifications/unread-count`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log('Notif Status:', notifResponse.status);
            console.log('Unread Count:', notifResponse.data);
        } catch (e: any) {
            console.error('Notif Error:', e.response?.status || e.message);
        }

    } catch (error: any) {
        console.error('Unexpected Error:', error.message);
    }
}

run();
