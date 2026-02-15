import axios from 'axios';

const API_URL = 'http://localhost:4000';

async function reproduce() {
  try {
    console.log('Logging in...');
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: 'waniqbal@gmail.com',
      password: 'Password123!',
    });
    const token = loginRes.data.accessToken;
    console.log('Got token:', token ? 'Yes' : 'No');

    if (!token) return;

    const headers = { Authorization: `Bearer ${token}` };

    console.log('\nCalling GET /services/list/my ...');
    try {
      const meRes = await axios.get(`${API_URL}/services/list/my`, { headers });
      console.log('Success /services/list/my:', meRes.status);
      console.log('Data length:', meRes.data.length);
    } catch (e: any) {
      console.error('Error /services/list/my:', e.response?.status, e.response?.data);
    }
  } catch (error: any) {
    console.error('Fatal error:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
  }
}

reproduce();
