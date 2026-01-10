# ============================================
# FreeTask Build with Java PATH Fix
# ============================================
# This script sets Java PATH and builds APK

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FreeTask APK Builder (Java PATH Fixed)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Configure Java
Write-Host "Step 1: Configuring Java environment..." -ForegroundColor Yellow
$javaHome = "C:\Program Files\Android\Android Studio\jbr"
$env:JAVA_HOME = $javaHome
$env:PATH = "$javaHome\bin;$env:PATH"

# Verify Java
Write-Host "Verifying Java..." -ForegroundColor Gray
try {
    $javaVersion = & java -version 2>&1
    Write-Host "  ✓ Java configured successfully" -ForegroundColor Green
    Write-Host "  Version: $($javaVersion[0])" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Java configuration failed" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Navigate to project
Write-Host "Step 2: Setting up project directory..." -ForegroundColor Yellow
Set-Location "C:\Users\USER\freetask-app-3\freetask_app"
Write-Host "  ✓ Directory: $(Get-Location)" -ForegroundColor Green
Write-Host ""

# Step 3: Clean build
Write-Host "Step 3: Cleaning previous build..." -ForegroundColor Yellow
flutter clean | Out-Null
Write-Host "  ✓ Clean completed" -ForegroundColor Green
Write-Host ""

# Step 4: Get dependencies
Write-Host "Step 4: Getting dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Dependencies resolved" -ForegroundColor Green
} else {
    Write-Host "  ✗ Dependencies failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 5: Build APK
Write-Host "Step 5: Building Release APK..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

$buildStart = Get-Date
flutter build apk --release

$buildEnd = Get-Date
$duration = $buildEnd - $buildStart

Write-Host ""

# Step 6: Check result
if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        
        Write-Host "APK Information:" -ForegroundColor Cyan
        Write-Host "  Location: $apkPath" -ForegroundColor White
        Write-Host "  Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        Write-Host "  Build Time: $([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor White
        Write-Host ""
        
        # Copy to Desktop
        $desktopPath = "$env:USERPROFILE\Desktop\FreeTask-release.apk"
        Copy-Item $apkPath $desktopPath -Force
        Write-Host "  ✓ APK copied to Desktop!" -ForegroundColor Green
        Write-Host "    $desktopPath" -ForegroundColor Gray
        Write-Host ""
        
        # Show warning about signing
        Write-Host "⚠ IMPORTANT NOTES:" -ForegroundColor Yellow
        Write-Host "  1. This APK is signed with DEBUG keys" -ForegroundColor Yellow
        Write-Host "  2. Before uploading to Play Store:" -ForegroundColor Yellow
        Write-Host "     - Run: .\create_keystore.ps1" -ForegroundColor White
        Write-Host "     - Create production keystore" -ForegroundColor White
        Write-Host "     - Rebuild with production signing" -ForegroundColor White
        Write-Host ""
        
    } else {
        Write-Host "  ⚠ APK file not found at expected location" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above for details." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Done!" -ForegroundColor Cyan
