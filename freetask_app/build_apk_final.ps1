$ErrorActionPreference = "Stop"

# Configuration
$flutterPath = "C:\Users\USER\flutter\bin\flutter.bat"
$projectDir = "C:\Users\USER\freetask-app-3\freetask_app"
$apkOutput = "$projectDir\build\app\outputs\flutter-apk\app-release.apk"
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$destinationPath = "$desktopPath\FreeTask-release.apk"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FreeTask APK Builder (Robust)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# validation
if (-not (Test-Path $flutterPath)) {
    Write-Host "ERROR: Flutter not found at $flutterPath" -ForegroundColor Red
    exit 1
}

Set-Location $projectDir
Write-Host "Working in: $projectDir" -ForegroundColor Gray

# Steps
try {
    Write-Host "Step 1: Cleaning..." -ForegroundColor Yellow
    & $flutterPath clean
    
    Write-Host "`nStep 2: Getting dependencies..." -ForegroundColor Yellow
    & $flutterPath pub get
    
    Write-Host "`nStep 3: Building Release APK..." -ForegroundColor Yellow
    Write-Host "This might take a few minutes..." -ForegroundColor DarkGray
    & $flutterPath build apk --release
    
    if (Test-Path $apkOutput) {
        Write-Host "`nStep 4: Copying to Desktop..." -ForegroundColor Yellow
        Copy-Item -Path $apkOutput -Destination $destinationPath -Force
        
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host "APK copied to: $destinationPath" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Green
    } else {
        throw "Build command finished but APK was not found at expected path."
    }

} catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
