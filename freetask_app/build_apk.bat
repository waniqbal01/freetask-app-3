@echo off
REM ============================================
REM FreeTask APK Builder - JAVA_HOME Fixed
REM ============================================

echo ========================================
echo FreeTask APK Builder
echo ========================================
echo.

REM Step 1: Set JAVA_HOME with proper quoting
echo Step 1: Configuring Java environment...
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM Verify Java
echo Verifying Java...
"%JAVA_HOME%\bin\java.exe" -version
if errorlevel 1 (
    echo ERROR: Java configuration failed
    pause
    exit /b 1
)
echo  [OK] Java configured successfully
echo.

REM Step 2: Navigate to project
echo Step 2: Setting up project directory...
cd /d "C:\Users\USER\freetask-app-3\freetask_app"
echo  [OK] Directory: %CD%
echo.

REM Step 3: Clean build
echo Step 3: Cleaning previous build...
call flutter clean >nul 2>&1
echo  [OK] Clean completed
echo.

REM Step 4: Get dependencies
echo Step 4: Getting dependencies...
call flutter pub get >nul 2>&1
if errorlevel 1 (
    echo ERROR: Dependencies failed
    pause
    exit /b 1
)
echo  [OK] Dependencies resolved
echo.

REM Step 5: Build APK
echo Step 5: Building Release APK...
echo This may take 5-10 minutes...
echo.

call flutter build apk --release

echo.

REM Step 6: Check result
if errorlevel 1 (
    echo ========================================
    echo BUILD FAILED
    echo ========================================
    echo.
    echo Check the error messages above.
    pause
    exit /b 1
)

echo ========================================
echo BUILD SUCCESSFUL!
echo ========================================
echo.

REM Copy APK to Desktop
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
if exist "%APK_PATH%" (
    echo APK Information:
    echo   Location: %APK_PATH%
    for %%A in ("%APK_PATH%") do echo   Size: %%~zA bytes
    echo.
    
    copy /Y "%APK_PATH%" "%USERPROFILE%\Desktop\FreeTask-release.apk" >nul
    echo  [OK] APK copied to Desktop!
    echo   %USERPROFILE%\Desktop\FreeTask-release.apk
    echo.
    
    echo IMPORTANT NOTES:
    echo   1. This APK is signed with DEBUG keys
    echo   2. Before uploading to Play Store:
    echo      - Run: create_keystore.ps1
    echo      - Create production keystore
    echo      - Rebuild with production signing
    echo.
) else (
    echo WARNING: APK file not found at expected location
)

echo Done!
echo.
pause
