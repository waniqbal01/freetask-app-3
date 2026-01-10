# ============================================
# FreeTask Build Fix Script
# ============================================
# This script fixes Gradle cache corruption and prepares for a clean build

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FreeTask Build Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill all Java processes
Write-Host "Step 1: Terminating Java processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcesses) {
    Stop-Process -Name java -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Terminated $($javaProcesses.Count) Java process(es)" -ForegroundColor Green
} else {
    Write-Host "  ℹ No Java processes running" -ForegroundColor Gray
}

# Also kill Dart processes
$dartProcesses = Get-Process dart -ErrorAction SilentlyContinue
if ($dartProcesses) {
    Stop-Process -Name dart -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Terminated Dart processes" -ForegroundColor Green
}

Start-Sleep -Seconds 2
Write-Host ""

# Step 2: Clean corrupted Gradle cache
Write-Host "Step 2: Cleaning corrupted Gradle wrapper cache..." -ForegroundColor Yellow
$gradleCachePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-7.6.3-all"
if (Test-Path $gradleCachePath) {
    try {
        Remove-Item -Recurse -Force $gradleCachePath -ErrorAction Stop
        Write-Host "  ✓ Deleted corrupted Gradle 7.6.3 cache" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ Could not delete some files (may be locked)" -ForegroundColor Yellow
        Write-Host "    Trying to delete individual files..." -ForegroundColor Gray
        Get-ChildItem $gradleCachePath -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "  ℹ Gradle cache already clean" -ForegroundColor Gray
}
Write-Host ""

# Step 3: Clean temporary Gradle directories
Write-Host "Step 3: Cleaning temporary build directories..." -ForegroundColor Yellow

# Clean C:\freetask_build if exists
if (Test-Path "C:\freetask_build") {
    Remove-Item -Recurse -Force "C:\freetask_build" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Deleted C:\freetask_build" -ForegroundColor Green
}

# Clean C:\gradle_temp if exists
if (Test-Path "C:\gradle_temp") {
    Remove-Item -Recurse -Force "C:\gradle_temp" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Deleted C:\gradle_temp" -ForegroundColor Green
}
Write-Host ""

# Step 4: Clean Flutter build artifacts
Write-Host "Step 4: Running Flutter clean..." -ForegroundColor Yellow
Set-Location "C:\Users\USER\freetask-app-3\freetask_app"
flutter clean | Out-Null
Write-Host "  ✓ Flutter clean completed" -ForegroundColor Green
Write-Host ""

# Step 5: Clean Android build directory
Write-Host "Step 5: Cleaning Android build directory..." -ForegroundColor Yellow
$androidBuildPath = "C:\Users\USER\freetask-app-3\freetask_app\android\build"
if (Test-Path $androidBuildPath) {
    Remove-Item -Recurse -Force $androidBuildPath -ErrorAction SilentlyContinue
    Write-Host "  ✓ Deleted Android build directory" -ForegroundColor Green
} else {
    Write-Host "  ℹ Android build directory already clean" -ForegroundColor Gray
}

$androidAppBuildPath = "C:\Users\USER\freetask-app-3\freetask_app\android\app\build"
if (Test-Path $androidAppBuildPath) {
    Remove-Item -Recurse -Force $androidAppBuildPath -ErrorAction SilentlyContinue
    Write-Host "  ✓ Deleted Android app build directory" -ForegroundColor Green
}
Write-Host ""

# Step 6: Restore dependencies
Write-Host "Step 6: Restoring Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Dependencies restored successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Failed to restore dependencies" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Environment Cleaned Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now build the APK:" -ForegroundColor Cyan
Write-Host "  flutter build apk --release" -ForegroundColor White
Write-Host ""
Write-Host "Or use the optimized build script:" -ForegroundColor Cyan
Write-Host "  .\build_apk_optimized.ps1" -ForegroundColor White
Write-Host ""
