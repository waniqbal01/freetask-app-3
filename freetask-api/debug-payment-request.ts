import axios from 'axios';
import * as jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const JWT_SECRET = 'super-secret-key'; // From .env

async function main() {
    // 1. Get Client User
    const job = await prisma.job.findUnique({
        where: { id: 9 },
        include: { client: true }
    });

    if (!job) {
        console.error('Job 9 not found');
        return;
    }

    const user = job.client;
    console.log(`User: ${user.email} (ID: ${user.id})`);

    // 2. Generate Token
    const token = jwt.sign(
        {
            userId: user.id,
            email: user.email,
            role: user.role
        },
        JWT_SECRET,
        { expiresIn: '1h' }
    );
    console.log('JWT Generated');

    // 3. Call Payment Endpoint
    try {
        const url = 'http://localhost:4000/payments/create';
        console.log(`POST ${url} for Job ${job.id}`);

        const response = await axios.post(
            url,
            { jobId: job.id, paymentGateway: 'billplz' },
            {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        );

        console.log('Success!', response.data);

    } catch (error: any) {
        console.error('------------------------------------------------');
        console.error('❌ Request Failed!');
        if (error.response) {
            console.error(`Status: ${error.response.status}`);
            console.error('Body:', JSON.stringify(error.response.data, null, 2));
        } else {
            console.error(error.message);
        }
        console.error('------------------------------------------------');
    }
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
