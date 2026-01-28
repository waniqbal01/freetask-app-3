import { PrismaClient } from '@prisma/client';
import axios from 'axios';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load env from current directory
dotenv.config({ path: path.join(__dirname, '.env') });

const prisma = new PrismaClient();
const BILL_ID = '13cff4a199e138a3';

async function main() {
    console.log('Starting Manual Payment Fix...');
    const apiKey = process.env.BILLPLZ_API_KEY;

    if (!apiKey) {
        console.error('ERROR: BILLPLZ_API_KEY not found in environment');
        return;
    }

    const isSandbox = process.env.BILLPLZ_SANDBOX === 'true';
    const baseUrl = isSandbox ? 'https://www.billplz-sandbox.com/api/v3' : 'https://www.billplz.com/api/v3';

    try {
        console.log(`Checking Billplz Bill ID: ${BILL_ID} on ${baseUrl}`);
        const response = await axios.get(`${baseUrl}/bills/${BILL_ID}`, {
            auth: { username: apiKey, password: '' }
        });

        const state = response.data.state;
        console.log(`Bill State: ${state}`);

        if (state === 'paid') {
            const payment = await prisma.payment.findUnique({ where: { transactionId: BILL_ID } });
            if (!payment) {
                console.error('Payment record not found in DB for this transaction ID');
                return;
            }

            if (payment.status === 'COMPLETED') {
                console.log('Payment is already COMPLETED in DB.');
                // Double check job status
                const job = await prisma.job.findUnique({ where: { id: payment.jobId } });
                console.log(`Job Status: ${job?.status}`);
                if (job?.status !== 'IN_PROGRESS') {
                    // Fix job status if out of sync
                    await prisma.job.update({
                        where: { id: payment.jobId },
                        data: { status: 'IN_PROGRESS' }
                    });
                    console.log('Fixed Job Status to IN_PROGRESS');
                }
                return;
            }

            console.log('Updating Database Records...');
            await prisma.$transaction(async (tx) => {
                // 1. Update Payment
                await tx.payment.update({
                    where: { id: payment.id },
                    data: { status: 'COMPLETED', paymentMethod: 'billplz' }
                });

                // 2. Update Job
                await tx.job.update({
                    where: { id: payment.jobId },
                    data: { status: 'IN_PROGRESS' }
                });

                // 3. Create Escrow
                await tx.escrow.upsert({
                    where: { jobId: payment.jobId },
                    create: {
                        jobId: payment.jobId,
                        amount: payment.amount,
                        status: 'HELD',
                    },
                    update: {
                        status: 'HELD',
                        amount: payment.amount,
                    },
                });
            });
            console.log('✅ SUCCESS: Job verified and updated to IN_PROGRESS');
        } else {
            console.log(`⚠️ Bill is NOT paid. Status is '${state}'. User needs to pay first.`);
        }

    } catch (e: any) {
        console.error('Error:', e.message);
        if (e.response) console.error('API Response:', JSON.stringify(e.response.data));
    } finally {
        await prisma.$disconnect();
    }
}

main();
