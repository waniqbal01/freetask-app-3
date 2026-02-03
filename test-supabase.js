const { Client } = require('pg');

async function testExactConfig() {
    console.log('Testing with EXACT config from screenshot...\n');

    // From screenshot: Transaction pooler, port 6543
    const password = 'Azli1970!123';
    const encodedPassword = encodeURIComponent(password);

    const configs = [
        {
            name: 'Config 1: Exact from screenshot (Transaction pooler, port 6543)',
            config: {
                connectionString: `postgresql://postgres.yvjyhbzmnlttplszqfzo:${encodedPassword}@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres`,
                ssl: { rejectUnauthorized: false }
            }
        },
        {
            name: 'Config 2: Same but without SSL rejection',
            config: {
                connectionString: `postgresql://postgres.yvjyhbzmnlttplszqfzo:${encodedPassword}@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres`,
                ssl: true
            }
        },
        {
            name: 'Config 3: Individual params (Transaction pooler)',
            config: {
                host: 'aws-1-ap-southeast-1.pooler.supabase.com',
                port: 6543,
                database: 'postgres',
                user: 'postgres.yvjyhbzmnlttplszqfzo',
                password: password,
                ssl: { rejectUnauthorized: false }
            }
        },
        {
            name: 'Config 4: Try with session mode param',
            config: {
                connectionString: `postgresql://postgres.yvjyhbzmnlttplszqfzo:${encodedPassword}@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?sslmode=require`,
                ssl: { rejectUnauthorized: false }
            }
        },
        {
            name: 'Config 5: Direct connection (port 5432) for migration',
            config: {
                host: 'aws-1-ap-southeast-1.pooler.supabase.com',
                port: 5432,
                database: 'postgres',
                user: 'postgres.yvjyhbzmnlttplszqfzo',
                password: password,
                ssl: { rejectUnauthorized: false }
            }
        },
        {
            name: 'Config 6: Try IPv4 only',
            config: {
                host: 'aws-1-ap-southeast-1.pooler.supabase.com',
                port: 6543,
                database: 'postgres',
                user: 'postgres.yvjyhbzmnlttplszqfzo',
                password: password,
                ssl: { rejectUnauthorized: false },
                // Force IPv4
                family: 4
            }
        },
    ];

    for (const { name, config } of configs) {
        console.log(`\n${'='.repeat(60)}`);
        console.log(`Testing: ${name}`);
        console.log(`${'='.repeat(60)}`);

        const client = new Client(config);

        try {
            console.log('Connecting...');
            await client.connect();

            console.log('✅ Connected! Querying database...');
            const result = await client.query('SELECT current_database(), current_user, version()');

            console.log('\n🎉🎉🎉 SUCCESS! 🎉🎉🎉\n');
            console.log(`Database: ${result.rows[0].current_database}`);
            console.log(`User: ${result.rows[0].current_user}`);
            console.log(`PostgreSQL: ${result.rows[0].version.split(',')[0]}`);

            // Test table query
            const tablesResult = await client.query(`
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
      `);
            console.log(`Public tables: ${tablesResult.rows[0].count}`);

            await client.end();

            console.log('\n✅ WORKING CONFIG:');
            console.log(JSON.stringify(config, null, 2));

            return config;

        } catch (err) {
            console.log(`❌ Failed: ${err.message}`);
            console.log(`Error code: ${err.code}`);
            if (err.code === 'ENOTFOUND') {
                console.log('   → DNS resolution failed - hostname not found');
            } else if (err.code === 'XX000') {
                console.log('   → Authentication failed - user/password issue');
            }
            try { await client.end(); } catch (e) { }
        }
    }

    console.log('\n❌ All configurations failed');
    return null;
}

testExactConfig().then(workingConfig => {
    if (workingConfig) {
        console.log('\n\n✅✅✅ READY TO MIGRATE! ✅✅✅');
    } else {
        console.log('\n\nNeed to try alternative approach...');
    }
});
