const { Client } = require('pg');

async function testConnections() {
    console.log('Testing database connections...\n');

    // Test Render connection
    const renderClient = new Client({
        connectionString: 'postgresql://freetask_user:UkrDuhHZcaZHfXP445xJiPsAGuIPwv3Q@dpg-d5f5pdi4d50c73chm34g-a.singapore-postgres.render.com/freetask',
        ssl: { rejectUnauthorized: false }
    });

    try {
        console.log('Connecting to Render...');
        await renderClient.connect();
        console.log('✅ Render connection successful');
        const result = await renderClient.query('SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = \'public\'');
        console.log(`   Tables found: ${result.rows[0].table_count}\n`);
        await renderClient.end();
    } catch (err) {
        console.error('❌ Render connection failed:', err.message);
    }

    // Test Supabase connection
    const supabaseClient = new Client({
        connectionString: 'postgresql://postgres.yvjyhbzmnlttplszqfzo:Azli1970!123@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres',
        ssl: { rejectUnauthorized: false }
    });

    try {
        console.log('Connecting to Supabase...');
        await supabaseClient.connect();
        console.log('✅ Supabase connection successful');
        const result = await supabaseClient.query('SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = \'public\'');
        console.log(`   Tables found: ${result.rows[0].table_count}\n`);
        await supabaseClient.end();
    } catch (err) {
        console.error('❌ Supabase connection failed:', err.message);
        console.error('Full error:', err);
    }
}

testConnections();
