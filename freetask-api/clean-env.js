const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '.env');
const backupPath = path.join(__dirname, '.env.bak');

try {
  // Read file as buffer
  const buffer = fs.readFileSync(envPath);
  
  // Create backup
  fs.writeFileSync(backupPath, buffer);
  console.log('Backup created at .env.bak');

  // Convert to string, filtering out null bytes and other weird control chars (keeping newlines)
  // The "spaced out" text often looks like UTF-16 LE (0 byte between chars).
  // We can try to decode based on detection, or just aggressively clean.
  // Let's try simple utf8 first, but strip nulls.
  let content = buffer.toString('utf8').replace(/\0/g, '');
  
  // Split into lines
  let lines = content.split(/\r?\n/);
  
  const processedKeys = new Set();
  const cleanedLines = [];
  
  // Process lines in reverse to keep the LAST occurrence (which we saw was the correct one)
  for (let i = lines.length - 1; i >= 0; i--) {
    let line = lines[i].trim();
    if (!line) continue;

    // Check if line is a key-value pair
    if (line.includes('=') && !line.startsWith('#')) {
      const key = line.split('=')[0].trim();
      if (processedKeys.has(key)) {
        console.log(`Removing duplicate/stale key: ${key}`);
        continue; // Skip duplicate
      }
      processedKeys.add(key);
    }
    
    // Add to cleaned lines (prepend because we are iterating backwards)
    cleanedLines.unshift(lines[i]); // Keep original formatting mostly
  }

  // Now refilter to ensure our target config is correct
  // The 'cleanedLines' now has unique keys (last one wins) and comments.
  
  // Let's reconstruct the file string
  let finalContent = cleanedLines.join('\n');
  
  // Fix the specific comment
  finalContent = finalContent.replace(
    '# Billplz Payment Gateway - SANDBOX MODE',
    '# Billplz Payment Gateway - PRODUCTION MODE'
  );

  // Write back
  fs.writeFileSync(envPath, finalContent, 'utf8');
  console.log('Successfully cleaned .env file');
  console.log('--------------------------------');
  console.log(finalContent);

} catch (err) {
  console.error('Error cleaning .env:', err);
}
