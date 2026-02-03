const { Client } = require('pg');

// Source database (Render)
const sourceClient = new Client({
    connectionString: 'postgresql://freetask_user:UkrDuhHZcaZHfXP445xJiPsAGuIPwv3Q@dpg-d5f5pdi4d50c73chm34g-a.singapore-postgres.render.com/freetask',
    ssl: { rejectUnauthorized: false }
});

// Destination database (Supabase)
const destClient = new Client({
    connectionString: 'postgresql://postgres.yvjyhbzmnlttplszqfzo:Azli1970!123@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres',
    ssl: { rejectUnauthorized: false }
});

async function migrateDatabase() {
    try {
        console.log('🚀 Starting database migration from Render to Supabase\n');

        // Connect to both databases
        console.log('📡 Connecting to Render database...');
        await sourceClient.connect();
        console.log('✅ Connected to Render\n');

        console.log('📡 Connecting to Supabase database...');
        await destClient.connect();
        console.log('✅ Connected to Supabase\n');

        // Step 1: Get all table names from source
        console.log('📋 Step 1: Getting list of tables...');
        const tablesResult = await sourceClient.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);

        const tables = tablesResult.rows.map(row => row.tablename);
        console.log(`Found ${tables.length} tables:`, tables.join(', '));
        console.log('');

        // Step 2: Export and import schema (DDL)
        console.log('🏗️  Step 2: Migrating table schemas...');
        for (const table of tables) {
            try {
                // Get CREATE TABLE statement
                const schemaResult = await sourceClient.query(`
          SELECT 
            'CREATE TABLE IF NOT EXISTS ' || quote_ident(tablename) || ' (' ||
            string_agg(
              quote_ident(attname) || ' ' || 
              format_type(atttypid, atttypmod) ||
              CASE WHEN attnotnull THEN ' NOT NULL' ELSE '' END ||
              CASE WHEN atthasdef THEN ' DEFAULT ' || pg_get_expr(adbin, adrelid) ELSE '' END,
              ', '
            ) || ');' as create_stmt
          FROM pg_attribute a
          LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
          JOIN pg_class c ON a.attrelid = c.oid
          JOIN pg_namespace n ON c.relnamespace = n.oid
          WHERE c.relname = $1
            AND n.nspname = 'public'
            AND a.attnum > 0
            AND NOT a.attisdropped
          GROUP BY tablename, c.oid;
        `, [table]);

                if (schemaResult.rows.length > 0) {
                    const createStmt = schemaResult.rows[0].create_stmt;

                    // Drop table if exists in destination
                    await destClient.query(`DROP TABLE IF EXISTS "${table}" CASCADE`);

                    // Create table in destination
                    await destClient.query(createStmt);
                    console.log(`  ✅ Created table: ${table}`);
                }
            } catch (err) {
                console.log(`  ⚠️  Warning on ${table}:`, err.message);
            }
        }
        console.log('');

        // Step 3: Copy data
        console.log('📦 Step 3: Copying table data...');
        let totalRows = 0;

        for (const table of tables) {
            try {
                // Get all data from source table
                const dataResult = await sourceClient.query(`SELECT * FROM "${table}"`);
                const rows = dataResult.rows;

                if (rows.length === 0) {
                    console.log(`  ⏭️  Skipped ${table} (empty table)`);
                    continue;
                }

                // Get column names
                const columns = Object.keys(rows[0]);
                const columnList = columns.map(col => `"${col}"`).join(', ');
                const placeholders = rows.map((_, rowIndex) => {
                    const valuePlaceholders = columns.map((_, colIndex) =>
                        `$${rowIndex * columns.length + colIndex + 1}`
                    ).join(', ');
                    return `(${valuePlaceholders})`;
                }).join(', ');

                // Flatten all values
                const values = rows.flatMap(row => columns.map(col => row[col]));

                // Insert into destination
                const insertQuery = `INSERT INTO "${table}" (${columnList}) VALUES ${placeholders}`;
                await destClient.query(insertQuery, values);

                totalRows += rows.length;
                console.log(`  ✅ Copied ${rows.length.toLocaleString()} rows to ${table}`);
            } catch (err) {
                console.log(`  ❌ Error copying ${table}:`, err.message);
            }
        }
        console.log(`\n📊 Total rows migrated: ${totalRows.toLocaleString()}\n`);

        // Step 4: Re-create indexes and constraints
        console.log('🔗 Step 4: Migrating indexes and constraints...');
        try {
            // Get primary keys
            const pkeysResult = await sourceClient.query(`
        SELECT tc.table_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = 'public'
        ORDER BY tc.table_name, kcu.ordinal_position
      `);

            const pkeysByTable = {};
            for (const row of pkeysResult.rows) {
                if (!pkeysByTable[row.table_name]) {
                    pkeysByTable[row.table_name] = [];
                }
                pkeysByTable[row.table_name].push(row.column_name);
            }

            // Add primary keys
            for (const [table, columns] of Object.entries(pkeysByTable)) {
                try {
                    const columnList = columns.map(col => `"${col}"`).join(', ');
                    await destClient.query(`
            ALTER TABLE "${table}" 
            ADD PRIMARY KEY (${columnList})
          `);
                    console.log(`  ✅ Added primary key to ${table}`);
                } catch (err) {
                    console.log(`  ⚠️  Warning: ${err.message}`);
                }
            }

            // Get indexes
            const indexesResult = await sourceClient.query(`
        SELECT
          schemaname,
          tablename,
          indexname,
          indexdef
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname NOT LIKE '%_pkey'
        ORDER BY tablename, indexname
      `);

            for (const row of indexesResult.rows) {
                try {
                    await destClient.query(row.indexdef);
                    console.log(`  ✅ Created index: ${row.indexname}`);
                } catch (err) {
                    console.log(`  ⚠️  Warning: ${err.message}`);
                }
            }
        } catch (err) {
            console.log(`  ⚠️  Warning migrating constraints:`, err.message);
        }

        console.log('\n🎉 Database migration completed successfully!\n');

        // Summary
        console.log('═══════════════════════════════════════════════');
        console.log('  MIGRATION SUMMARY');
        console.log('═══════════════════════════════════════════════');
        console.log(`  ✅ Tables migrated: ${tables.length}`);
        console.log(`  ✅ Total rows: ${totalRows.toLocaleString()}`);
        console.log('═══════════════════════════════════════════════\n');

        console.log('📋 Next Steps:');
        console.log('1. Update .env file with Supabase connection');
        console.log('2. Test your API with: npm run start:dev');
        console.log('3. Verify data in Supabase dashboard\n');

    } catch (error) {
        console.error('\n❌ Migration failed:', error.message);
        console.error('Stack trace:', error.stack);
        process.exit(1);
    } finally {
        // Close connections
        await sourceClient.end();
        await destClient.end();
        console.log('✅ Database connections closed\n');
    }
}

// Run migration
migrateDatabase();
