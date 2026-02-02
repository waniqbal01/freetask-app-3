#!/usr/bin/env node

/**
 * Diagnostic Script - Run before main app to identify startup issues
 * This will test all critical components and show EXACT error if something fails
 */

console.log('\n='.repeat(60));
console.log('🔍 FREETASK API - STARTUP DIAGNOSTICS');
console.log('='.repeat(60));
console.log('Time:', new Date().toISOString());
console.log('Node version:', process.version);
console.log('');

// 1. Check Environment Variables
console.log('📋 STEP 1: Checking Environment Variables');
console.log('-'.repeat(60));

const requiredVars = [
    'NODE_ENV',
    'PORT',
    'DATABASE_URL',
    'JWT_SECRET',
    'JWT_EXPIRES_IN',
    'JWT_REFRESH_EXPIRES_IN',
    'ALLOWED_ORIGINS',
    'TRUST_PROXY'
];

let envCheckPassed = true;

requiredVars.forEach(varName => {
    const value = process.env[varName];
    if (!value || value.trim().length === 0) {
        console.log(`❌ ${varName}: NOT SET or EMPTY`);
        envCheckPassed = false;
    } else {
        // Mask sensitive values
        if (varName.includes('SECRET') || varName.includes('DATABASE_URL')) {
            console.log(`✅ ${varName}: SET (${value.substring(0, 10)}...)`);
        } else {
            console.log(`✅ ${varName}: ${value}`);
        }
    }
});

if (!envCheckPassed) {
    console.error('\n❌ FAILED: Missing required environment variables!');
    process.exit(1);
}

console.log('✅ All required environment variables are set\n');

// 2. Check Production-specific Requirements
if (process.env.NODE_ENV === 'production') {
    console.log('📋 STEP 2: Checking Production Requirements');
    console.log('-'.repeat(60));

    if (!process.env.JWT_REFRESH_EXPIRES_IN) {
        console.error('❌ JWT_REFRESH_EXPIRES_IN is required in production!');
        process.exit(1);
    }

    if (process.env.ALLOWED_ORIGINS === '*') {
        console.warn('⚠️  WARNING: ALLOWED_ORIGINS is set to * (all origins allowed)');
    }

    console.log('✅ Production requirements met\n');
}

// 3. Test Database Connection
console.log('📋 STEP 3: Testing Database Connection');
console.log('-'.repeat(60));

async function testDatabase() {
    try {
        const { PrismaClient } = require('@prisma/client');
        const prisma = new PrismaClient({
            log: ['error', 'warn'],
        });

        console.log('Attempting to connect to database...');
        await prisma.$connect();
        console.log('✅ Database connected successfully');

        console.log('Running test query...');
        await prisma.$queryRaw`SELECT 1 as test`;
        console.log('✅ Test query successful');

        await prisma.$disconnect();
        console.log('✅ Database disconnected cleanly\n');

        return true;
    } catch (error) {
        console.error('❌ DATABASE CONNECTION FAILED!');
        console.error('Error type:', error.constructor.name);
        console.error('Error message:', error.message);
        if (error.code) console.error('Error code:', error.code);
        if (error.meta) console.error('Error meta:', error.meta);
        console.error('\nFull error:', error);
        return false;
    }
}

// 4. Check if dist/main.js exists
console.log('📋 STEP 4: Checking Build Output');
console.log('-'.repeat(60));

const fs = require('fs');
const path = require('path');

const mainJsPath = path.join(__dirname, 'dist', 'main.js');
if (fs.existsSync(mainJsPath)) {
    const stats = fs.statSync(mainJsPath);
    console.log(`✅ dist/main.js exists (${stats.size} bytes)`);
} else {
    console.error('❌ dist/main.js NOT FOUND! Build may have failed.');
    process.exit(1);
}

const distFiles = fs.readdirSync(path.join(__dirname, 'dist'));
console.log(`✅ Found ${distFiles.length} files in dist/\n`);

// Run async tests
async function runDiagnostics() {
    const dbOk = await testDatabase();

    console.log('='.repeat(60));
    console.log('📊 DIAGNOSTIC SUMMARY');
    console.log('='.repeat(60));
    console.log(`Environment Variables: ✅ PASS`);
    console.log(`Database Connection: ${dbOk ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`Build Output: ✅ PASS`);
    console.log('='.repeat(60));

    if (!dbOk) {
        console.error('\n❌ DIAGNOSTICS FAILED - Cannot proceed to app startup');
        console.error('Fix the database connection issue above and try again.');
        process.exit(1);
    }

    console.log('\n✅ ALL DIAGNOSTICS PASSED - Ready to start app');
    console.log('='.repeat(60));
    console.log('\n');
}

runDiagnostics().catch(error => {
    console.error('\n❌ DIAGNOSTIC SCRIPT CRASHED:');
    console.error(error);
    process.exit(1);
});
