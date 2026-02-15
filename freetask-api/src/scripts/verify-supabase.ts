
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { join } from 'path';
import * as fs from 'fs';

// Load .env from project root
dotenv.config({ path: join(__dirname, '../../.env') });

async function checkSupabase() {
    const logFile = join(__dirname, 'verify_output.txt');
    const log = (msg: string) => {
        console.log(msg);
        fs.appendFileSync(logFile, msg + '\n');
    };

    fs.writeFileSync(logFile, ''); // Clear file

    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_KEY;
    const bucketName = process.env.SUPABASE_BUCKET || 'uploads';

    log('Checking Supabase connection...');
    log(`URL: ${supabaseUrl}`);
    log(`Key: ${supabaseKey ? (supabaseKey.substring(0, 10) + '...') : 'undefined'}`);
    log(`Bucket: ${bucketName}`);

    if (!supabaseUrl || !supabaseKey) {
        log('❌ Missing credentials in .env');
        return;
    }

    // Check key format
    if (!supabaseKey.startsWith('ey')) {
        log('⚠️ WARNING: SUPABASE_KEY does not start with "ey". It looks like an invalid JWT.');
        log(`   Current format starts with: ${supabaseKey.substring(0, 5)}`);
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    try {
        // Try to list files in the bucket
        const { data, error } = await supabase.storage.from(bucketName).list();

        if (error) {
            log(`❌ Failed to connect/list bucket: ${error.message}`);
            log(`   Error Details: ${JSON.stringify(error)}`);
        } else {
            log('✅ Connection successful!');
            log(`Found ${data.length} files in bucket '${bucketName}'.`);

            // Try to upload a test file
            log('Attempting to upload test file...');
            const testFileName = `test-upload-${Date.now()}.txt`;
            const { data: uploadData, error: uploadError } = await supabase.storage
                .from(bucketName)
                .upload(testFileName, 'Hello World', {
                    contentType: 'text/plain',
                    upsert: true,
                });

            if (uploadError) {
                log(`❌ Failed to upload file: ${uploadError.message}`);
                log(`   Error Details: ${JSON.stringify(uploadError)}`);

                if (uploadError.message.includes('Bucket not found') || (uploadError as any).body?.includes('Bucket not found')) {
                    log('Attempting to create bucket "uploads"...');
                    const { data: bucketData, error: bucketError } = await supabase.storage.createBucket(bucketName, {
                        public: true, // Make it public
                        fileSizeLimit: 10485760, // 10MB
                    });

                    if (bucketError) {
                        log(`❌ Failed to create bucket: ${bucketError.message}`);
                    } else {
                        log(`✅ Bucket "${bucketName}" created successfully!`);
                        // Retry upload?
                    }
                }
            } else {
                log(`✅ Upload successful: ${testFileName}`);
                const { data: publicUrlData } = supabase.storage.from(bucketName).getPublicUrl(testFileName);
                log(`ℹ️ Public URL: ${publicUrlData.publicUrl}`);

                // Check if public access works
                try {
                    // We can't easily curl from here without axios/fetch, but we can print it
                    // The user 400 error suggests the bucket might not be effectively public or policy missing
                    log('Checking bucket public status...');
                    const { data: bucketInfo, error: bucketInfoError } = await supabase.storage.getBucket(bucketName);
                    if (bucketInfo) {
                        log(`Bucket Public: ${bucketInfo.public}`);
                        if (!bucketInfo.public) {
                            log('⚠️ Bucket is NOT public. Updating...');
                            const { error: updateError } = await supabase.storage.updateBucket(bucketName, { public: true });
                            if (updateError) log(`❌ Failed to update bucket: ${updateError.message}`);
                            else log('✅ Bucket updated to public.');
                        }
                    } else {
                        log(`⚠️ Could not get bucket info: ${bucketInfoError?.message}`);
                    }

                } catch (e) {
                    log(`⚠️ Error checking public status: ${e}`);
                }

                // Clean up
                await supabase.storage.from(bucketName).remove([testFileName]);
                log('✅ Test file cleaned up.');
            }
        }
    } catch (err) {
        log(`❌ Exception: ${err}`);
    }
}

checkSupabase();
