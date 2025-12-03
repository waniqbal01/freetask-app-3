-- Check if wan03@gmail.com exists
SELECT id, email, name, role, "createdAt" 
FROM "User" 
WHERE email = 'wan03@gmail.com';
