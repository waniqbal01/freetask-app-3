# FreeTask APK Build Fix Script
# Run this in PowerShell as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FreeTask APK Build Permission Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Step 1: Add Windows Defender Exclusions
Write-Host "Step 1: Adding Windows Defender Exclusions..." -ForegroundColor Yellow

try {
    Add-MpPreference -ExclusionPath "C:\Users\USER\freetask-app-3" -ErrorAction Stop
    Write-Host "✓ Added exclusion for project directory" -ForegroundColor Green
} catch {
    Write-Host "  Already excluded or error: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

try {
    Add-MpPreference -ExclusionPath "$env:USERPROFILE\.gradle" -ErrorAction Stop
    Write-Host "✓ Added exclusion for .gradle cache" -ForegroundColor Green
} catch {
    Write-Host "  Already excluded or error: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

try {
    Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Android" -ErrorAction Stop
    Write-Host "✓ Added exclusion for Android SDK" -ForegroundColor Green
} catch {
    Write-Host "  Already excluded or error: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host ""

# Step 2: Kill all Java/Gradle processes
Write-Host "Step 2: Killing Java/Gradle processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*java*" -or $_.ProcessName -like "*gradle*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "✓ Processes killed" -ForegroundColor Green
Write-Host ""

# Step 3: Remove locked Gradle cache
Write-Host "Step 3: Removing .gradle cache..." -ForegroundColor Yellow

if (Test-Path "$env:USERPROFILE\.gradle") {
    try {
        # Try to take ownership and remove
        takeown /F "$env:USERPROFILE\.gradle" /R /D Y 2>&1 | Out-Null
        icacls "$env:USERPROFILE\.gradle" /grant administrators:F /T 2>&1 | Out-Null
        Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle" -ErrorAction Stop
        Write-Host "✓ .gradle cache removed" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not fully remove cache: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "✓ .gradle cache already clean" -ForegroundColor Green
}

Write-Host ""

# Step 4: Clean Flutter project
Write-Host "Step 4: Cleaning Flutter project..." -ForegroundColor Yellow
Set-Location "C:\Users\USER\freetask-app-3\freetask_app"
flutter clean | Out-Null
Write-Host "✓ Flutter project cleaned" -ForegroundColor Green
Write-Host ""

# Step 5: Build APK
Write-Host "Step 5: Building APK..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Cyan
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! APK Built Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Location:" -ForegroundColor Cyan
    Write-Host "  build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host ""
    
    if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
        $apkSize = (Get-Item "build\app\outputs\flutter-apk\app-release.apk").Length / 1MB
        Write-Host "  Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Build Failed - Try Alternative Method" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Use 'flutter run --release' with connected device" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
