const { Client } = require('pg');
const fs = require('fs');

// Render database connection  
const renderClient = new Client({
    connectionString: 'postgresql://freetask_user:UkrDuhHZcaZHfXP445xJiPsAGuIPwv3Q@dpg-d5f5pdi4d50c73chm34g-a.singapore-postgres.render.com/freetask',
    ssl: { rejectUnauthorized: false }
});

// Built-in PostgreSQL types that should NOT be quoted
const BUILTIN_TYPES = new Set([
    'integer', 'bigint', 'smallint',
    'text', 'varchar', 'character varying', 'char', 'character',
    'boolean', 'bool',
    'numeric', 'decimal', 'real', 'double precision',
    'timestamp', 'timestamp without time zone', 'timestamp with time zone', 'timestamptz',
    'date', 'time', 'interval',
    'jsonb', 'json',
    'uuid', 'bytea', 'inet', 'cidr', 'macaddr',
    'array', 'hstore'
]);

async function exportToSQL() {
    try {
        console.log('📦 Connecting to Render database...');
        await renderClient.connect();
        console.log('✅ Connected!\n');

        // Get all tables
        const tablesResult = await renderClient.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);

        const tables = tablesResult.rows.map(row => row.tablename);
        console.log(`Found ${tables.length} tables:`, tables.join(', '));
        console.log('\n📝 Generating SQL export file...\n');

        let sqlContent = `-- Freetask Database Export from Render
-- Generated: ${new Date().toISOString()}
-- Tables: ${tables.length}

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';

`;

        // Export each table
        for (const table of tables) {
            console.log(`  Processing ${table}...`);

            // Get table schema with proper type handling
            const schemaQuery = await renderClient.query(`
        SELECT 
          c.column_name,
          CASE 
            WHEN c.data_type = 'USER-DEFINED' THEN c.udt_name
            ELSE c.data_type
          END as data_type,
          c.character_maximum_length,
          c.is_nullable,
          c.column_default
        FROM information_schema.columns c
        WHERE c.table_schema = 'public' AND c.table_name = $1
        ORDER BY c.ordinal_position
      `, [table]);

            // Get data
            const dataResult = await renderClient.query(`SELECT * FROM "${table}"`);

            sqlContent += `\n-- Table: ${table}\n`;
            sqlContent += `DROP TABLE IF EXISTS "${table}" CASCADE;\n`;
            sqlContent += `CREATE TABLE "${table}" (\n`;

            const columnDefs = schemaQuery.rows.map(col => {
                let def = `  "${col.column_name}" `;

                // Handle different data types
                let typeName = col.data_type.toLowerCase();

                if (typeName === 'character varying') {
                    def += 'varchar';
                    if (col.character_maximum_length) {
                        def += `(${col.character_maximum_length})`;
                    }
                } else if (typeName === 'timestamp without time zone') {
                    def += 'timestamp';
                } else if (typeName === 'timestamp with time zone') {
                    def += 'timestamptz';
                } else if (typeName === 'character') {
                    def += `char(${col.character_maximum_length})`;
                } else if (BUILTIN_TYPES.has(typeName)) {
                    // Built-in type - use without quotes
                    def += typeName;
                } else {
                    // User-defined type (enum) - use WITH quotes
                    def += `"${col.data_type}"`;
                }

                if (col.is_nullable === 'NO') {
                    def += ' NOT NULL';
                }
                if (col.column_default) {
                    def += ` DEFAULT ${col.column_default}`;
                }
                return def;
            }).join(',\n');

            sqlContent += columnDefs + '\n);\n\n';

            // Add data
            if (dataResult.rows.length > 0) {
                const columns = Object.keys(dataResult.rows[0]);
                const columnList = columns.map(c => `"${c}"`).join(', ');

                for (const row of dataResult.rows) {
                    const values = columns.map(col => {
                        const val = row[col];
                        if (val === null) return 'NULL';
                        if (typeof val === 'string') return `'${val.replace(/'/g, "''")}'`;
                        if (val instanceof Date) return `'${val.toISOString()}'`;
                        if (typeof val === 'boolean') return val ? 'true' : 'false';
                        if (typeof val === 'object') return `'${JSON.stringify(val).replace(/'/g, "''")}'`;
                        return val;
                    }).join(', ');

                    sqlContent += `INSERT INTO "${table}" (${columnList}) VALUES (${values});\n`;
                }
                sqlContent += '\n';
            }

            console.log(`    ✅ Exported ${dataResult.rows.length} rows`);
        }

        // Save to file
        const filename = `render-export-final-${Date.now()}.sql`;
        fs.writeFileSync(filename, sqlContent);

        console.log(`\n✅ Export complete!`);
        console.log(`📁 File saved: ${filename}`);
        console.log(`📊 Size: ${(fs.statSync(filename).size / 1024).toFixed(2)} KB\n`);

        await renderClient.end();

        return filename;

    } catch (err) {
        console.error('❌ Error:', err.message);
        await renderClient.end();
    }
}

exportToSQL().then(filename => {
    if (filename) {
        console.log('═'.repeat(70));
        console.log('READY TO IMPORT!');
        console.log('═'.repeat(70));
        console.log('1. Go to Supabase Dashboard > SQL Editor');
        console.log('2. First run: setup-enums.sql (if not done yet)');
        console.log(`3. Then run: ${filename}`);
        console.log('4. Verify tables in Table Editor\n');
        console.log('NOTE: Built-in types (integer, text, etc.) are now UNQUOTED');
        console.log('      Enum types (UserRole, JobStatus, etc.) remain QUOTED\n');
    }
});
