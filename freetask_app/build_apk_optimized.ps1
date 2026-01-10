# ============================================
# FreeTask Optimized APK Builder
# ============================================
# This script builds APK with optimized settings

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FreeTask Optimized APK Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ensure we're in the right directory
Set-Location "C:\Users\USER\freetask-app-3\freetask_app"

# Check if environment is clean
Write-Host "Checking build environment..." -ForegroundColor Yellow
$gradleCachePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-7.6.3-all"
$needsCleanup = $false

# Check for running Java processes
$javaProcesses = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcesses) {
    Write-Host "  ⚠ Java processes are running" -ForegroundColor Yellow
    $needsCleanup = $true
}

# Check if Gradle cache exists and might be corrupted
if (Test-Path $gradleCachePath) {
    $cacheSize = (Get-ChildItem $gradleCachePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($cacheSize -eq 0 -or $cacheSize -eq $null) {
        Write-Host "  ⚠ Gradle cache appears corrupted" -ForegroundColor Yellow
        $needsCleanup = $true
    }
}

if ($needsCleanup) {
    Write-Host ""
    Write-Host "Build environment needs cleanup. Running fix script first..." -ForegroundColor Yellow
    Write-Host ""
    & .\fix_build_environment.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Fix script failed. Exiting..." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
} else {
    Write-Host "  ✓ Build environment is clean" -ForegroundColor Green
    Write-Host ""
}

# Start build
Write-Host "Starting APK build..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes depending on your system." -ForegroundColor Gray
Write-Host ""

# Build with verbose output for debugging
$buildStartTime = Get-Date
flutter build apk --release --verbose

$buildEndTime = Get-Date
$buildDuration = $buildEndTime - $buildStartTime

Write-Host ""

if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "APK Details:" -ForegroundColor Cyan
        Write-Host "  Location: $apkPath" -ForegroundColor White
        Write-Host "  Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
        Write-Host "  Build Time: $([math]::Round($buildDuration.TotalMinutes, 1)) minutes" -ForegroundColor White
        Write-Host ""
        
        # Copy to Desktop
        $desktopPath = "$env:USERPROFILE\Desktop\FreeTask-release.apk"
        Copy-Item $apkPath $desktopPath -Force
        Write-Host "  ✓ APK copied to Desktop!" -ForegroundColor Green
        Write-Host ""
        
        # Show signing info warning
        Write-Host "⚠ IMPORTANT: This APK is signed with DEBUG keys!" -ForegroundColor Yellow
        Write-Host "  Before uploading to Google Play Console, you must:" -ForegroundColor Yellow
        Write-Host "  1. Generate a production keystore" -ForegroundColor White
        Write-Host "  2. Configure signing in build.gradle.kts" -ForegroundColor White
        Write-Host "  3. Rebuild with production signing" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Write-Host "If Gradle cache errors persist, try:" -ForegroundColor Yellow
    Write-Host "  1. Run: .\fix_build_environment.ps1" -ForegroundColor White
    Write-Host "  2. Restart your computer" -ForegroundColor White
    Write-Host "  3. Try building again" -ForegroundColor White
    Write-Host ""
    exit 1
}
