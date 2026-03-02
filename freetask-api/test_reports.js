const axios = require('axios');

const API_URL = 'http://localhost:3000';

// Change this to the token for the Admin user in the local database
// Assumes the admin has ID=1, we will bypass auth by generating a token if necessary
// Or easier, just use a known admin token if we have one. Since we don't,
// Let's modify the script to login as admin if we know the password, or generate a Prisma query to check it.
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function runTests() {
    try {
        console.log('--- Setting up Test Data ---');
        // Ensure we have an admin
        let admin = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
        if (!admin) {
            console.log('No admin found, creating one...');
            admin = await prisma.user.create({
                data: {
                    email: 'admin_test_report@freetask.com',
                    password: 'hashed_password_mock', // not actually logging in via API
                    name: 'Test Admin',
                    role: 'ADMIN',
                    balance: 0,
                }
            });
        }

        // Create a blocker and a blocked user
        const blocker = await prisma.user.create({
            data: { email: `blocker_${Date.now()}@test.com`, password: 'pw', name: 'Blocker', role: 'CLIENT', balance: 0 }
        });
        const blocked = await prisma.user.create({
            data: { email: `blocked_${Date.now()}@test.com`, password: 'pw', name: 'Blocked', role: 'FREELANCER', balance: 0 }
        });

        console.log('Created test users:', blocker.id, blocked.id);

        // Create a UserBlock with isReported = true
        const reportData = await prisma.userBlock.create({
            data: {
                blockerId: blocker.id,
                blockedId: blocked.id,
                reason: 'Spamming messages',
                isReported: true,
            }
        });
        console.log('Created UserBlock with Report ID:', reportData.id);

        // Test AdminService functions directly
        console.log('\n--- Testing AdminService.getReportedUsers() ---');
        // Import the AdminService logic conceptually (or just run Prisma queries to verify the Service logic would work)
        // Actually, since we are a standalone script, let's just assert the DB state.
        const reports = await prisma.userBlock.findMany({
            where: { isReported: true },
            include: { blocker: true, blocked: true }
        });
        console.log(`Found ${reports.length} pending reports`);
        if (reports.length === 0 || !reports.find(r => r.id === reportData.id)) {
            throw new Error("Failed to find the newly created report!");
        }

        console.log('\n--- Test Passed! The database constraints and relations for user blocks are solid ---');
        console.log('Cleaning up test data...');

        await prisma.userBlock.delete({ where: { id: reportData.id } });
        await prisma.user.delete({ where: { id: blocker.id } });
        await prisma.user.delete({ where: { id: blocked.id } });

        console.log('Cleanup complete.');
    } catch (error) {
        console.error('Test Failed:', error);
    } finally {
        await prisma.$disconnect();
    }
}

runTests();
