# Quick APK Build - Alternative Method
# If main script fails, use this simpler approach

Write-Host "Quick Build Alternative Method" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

Set-Location "C:\Users\USER\freetask-app-3\freetask_app"

# Option 1: Try without Gradle wrapper
Write-Host "Attempting direct Gradle build..." -ForegroundColor Yellow

$env:GRADLE_USER_HOME = "C:\temp\gradle_cache"
New-Item -ItemType Directory -Force -Path "C:\temp\gradle_cache" | Out-Null

flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Direct build failed. Trying debug APK instead..." -ForegroundColor Yellow
    flutter build apk --debug
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Debug APK built successfully!" -ForegroundColor Green
        Write-Host "Location: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Note: This is a debug APK (larger size, not optimized)" -ForegroundColor Yellow
        Write-Host "Good for testing, but use release APK for production" -ForegroundColor Yellow
    }
}
