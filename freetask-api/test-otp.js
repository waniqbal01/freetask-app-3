const axios = require('axios');
const { Client } = require('pg');

const dbUrl = 'postgresql://postgres.yviyhbzkmlttplszqfzo:Azli1970%21123@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true';

async function testOtpFlow() {
    const client = new Client({ connectionString: dbUrl });

    try {
        await client.connect();

        const email = 'test_otp_' + Date.now() + '@example.com';
        const password = 'Password123!';
        const name = 'Test User';

        console.log('[1] Menguji pendaftaran dengan e-mel: ' + email);
        const regRes = await axios.post('http://127.0.0.1:4000/auth/register', {
            email, password, name, role: 'CLIENT'
        });
        console.log('✅ Pendaftaran berjaya. Mesej:', regRes.data.message);

        console.log('\n[2] Cuba log masuk sebelum sahkan e-mel (sepatutnya gagal)...');
        try {
            await axios.post('http://127.0.0.1:4000/auth/login', { email, password });
            console.log('❌ Log masuk berjaya (Ralat! Sepatutnya tidak dibenarkan)');
        } catch (e) {
            if (e.response && e.response.status === 401) {
                console.log('✅ Log masuk dihalang dengan betul. Mesej:', e.response.data.message);
            } else {
                console.log('❌ Ralat tidak dijangka:', e.message);
            }
        }

        console.log('\n[3] Mengambil OTP dari pangkalan data...');
        const dbRes = await client.query('SELECT "otpCode" FROM "User" WHERE email = $1', [email]);
        if (dbRes.rows.length === 0) throw new Error('User not found in DB');

        const otp = dbRes.rows[0].otpCode;
        console.log('✅ Kod OTP dijumpai di DB:', otp);

        console.log('\n[4] Menguji pengesahan OTP (verify-otp)...');
        const verifyRes = await axios.post('http://127.0.0.1:4000/auth/verify-otp', {
            email, otp
        });
        console.log('✅ OTP Disahkan! Token diterima:', !!verifyRes.data.accessToken);

        console.log('\n[5] Cuba log masuk selepas sahkan e-mel...');
        const loginRes = await axios.post('http://127.0.0.1:4000/auth/login', { email, password });
        console.log('✅ Log masuk berjaya! Token diterima:', !!loginRes.data.accessToken);

    } catch (err) {
        if (err.response) {
            console.error('❌ Ujian Gagal (API):', err.response.data);
        } else {
            console.error('❌ Ujian Gagal (System):', err.message);
        }
    } finally {
        await client.end();
    }
}

testOtpFlow();
