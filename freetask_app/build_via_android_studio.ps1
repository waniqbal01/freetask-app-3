# APK Generator via Android Studio
# Method 2: Use Android Studio's built-in build system

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build APK via Android Studio" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$projectPath = "C:\Users\USER\freetask-app-3\freetask_app"

Write-Host "Manual Steps to Build via Android Studio:" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Open Android Studio" -ForegroundColor White
Write-Host "   → File → Open" -ForegroundColor Gray
Write-Host "   → Navigate to: $projectPath\android" -ForegroundColor Cyan
Write-Host ""

Write-Host "2. Wait for Gradle sync to complete" -ForegroundColor White
Write-Host "   (May take 2-3 minutes)" -ForegroundColor Gray
Write-Host ""

Write-Host "3. In Terminal inside Android Studio, run:" -ForegroundColor White
Write-Host "   flutter build apk --release" -ForegroundColor Cyan
Write-Host ""
Write-Host "   OR use Gradle directly:" -ForegroundColor White
Write-Host "   .\gradlew assembleRelease" -ForegroundColor Cyan
Write-Host ""

Write-Host "4. APK will be at:" -ForegroundColor White
Write-Host "   ..\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Alternative: Build → Generate Signed Bundle/APK" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. In Android Studio:" -ForegroundColor White
Write-Host "   → Build → Generate Signed Bundle / APK" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Select APK" -ForegroundColor White
Write-Host ""

Write-Host "3. Create new keystore OR use debug keystore:" -ForegroundColor White
Write-Host "   Debug keystore location:" -ForegroundColor Gray
Write-Host "   $env:USERPROFILE\.android\debug.keystore" -ForegroundColor Cyan
Write-Host "   Password: android" -ForegroundColor Gray
Write-Host "   Alias: androiddebugkey" -ForegroundColor Gray
Write-Host "   Alias password: android" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Select 'release' build variant" -ForegroundColor White
Write-Host ""

Write-Host "5. Click Finish" -ForegroundColor White
Write-Host ""

Write-Host "APK will be generated without permission issues!" -ForegroundColor Green
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
