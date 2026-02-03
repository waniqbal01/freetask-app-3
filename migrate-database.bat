@echo off
echo ========================================
echo  Database Migration: Render to Supabase
echo ========================================
echo.

REM Create backup directory
if not exist "db-backup" mkdir db-backup

REM Set timestamp
set timestamp=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set timestamp=%timestamp: =0%

REM Database URLs
set RENDER_URL=postgresql://freetask_user:UkrDuhHZcaZHfXP445xJiPsAGuIPwv3Q@dpg-d5f5pdi4d50c73chm34g-a.singapore-postgres.render.com/freetask
set SUPABASE_URL=postgresql://postgres.yvjyhbzmnlttplszqfzo:Azli1970!123@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres

set BACKUP_FILE=db-backup\render-backup-%timestamp%.sql

echo Step 1: Exporting database from Render...
echo.
pg_dump "%RENDER_URL%" > "%BACKUP_FILE%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to export database from Render
    echo.
    echo Make sure PostgreSQL tools are installed:
    echo Download from: https://www.postgresql.org/download/
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Export completed!
echo Backup saved to: %BACKUP_FILE%
echo.

echo Step 2: Importing database to Supabase...
echo.
psql "%SUPABASE_URL%" < "%BACKUP_FILE%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to import database to Supabase
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Migration Completed Successfully!
echo ========================================
echo.
echo Next steps:
echo 1. Update your .env file with Supabase connection
echo 2. Test your application
echo 3. Verify all data migrated correctly
echo.
pause
