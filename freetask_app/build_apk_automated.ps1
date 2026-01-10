# Alternative APK Generator - Automated
# Windows has issues with complex paths - let's use C:\temp

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "APK Generator - Simple Path Method (Automated)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create simple working directory
$simplePath = "C:\freetask_build"
$sourcePath = "C:\Users\USER\freetask-app-3\freetask_app"

Write-Host "Step 1: Creating build directory..." -ForegroundColor Yellow

# Remove if exists
if (Test-Path $simplePath) {
    Remove-Item -Recurse -Force $simplePath -ErrorAction SilentlyContinue
}

# Create fresh directory
New-Item -ItemType Directory -Force -Path $simplePath | Out-Null
Write-Host "✓ Created: $simplePath" -ForegroundColor Green
Write-Host ""

# Step 2: Copy project
Write-Host "Step 2: Copying project to simple path..." -ForegroundColor Yellow
Write-Host "This may take a minute..." -ForegroundColor DarkGray

# Copy minimal required files
$itemsToCopy = @(
    "lib",
    "android",
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml"
)

foreach ($item in $itemsToCopy) {
    $source = Join-Path $sourcePath $item
    $dest = Join-Path $simplePath $item
    
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $dest -Recurse -Force
        Write-Host "  ✓ Copied $item" -ForegroundColor Green
    }
}

Write-Host ""

# Step 3: Set Gradle cache to simple location
Write-Host "Step 3: Configuring Gradle cache..." -ForegroundColor Yellow
$env:GRADLE_USER_HOME = "C:\gradle_temp"
New-Item -ItemType Directory -Force -Path "C:\gradle_temp" | Out-Null
Write-Host "✓ Gradle cache: C:\gradle_temp" -ForegroundColor Green
Write-Host ""

# Step 4: Build
Write-Host "Step 4: Building APK..." -ForegroundColor Yellow
Write-Host "Location: $simplePath" -ForegroundColor Cyan
Write-Host ""

Set-Location $simplePath

# Clean first
flutter clean | Out-Null

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor DarkGray
flutter pub get | Out-Null

# Build APK
Write-Host "Building release APK..." -ForegroundColor DarkGray
Write-Host ""
flutter build apk --release

Write-Host ""

# Step 5: Copy APK back to original location
if ($LASTEXITCODE -eq 0) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! APK Built!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $apkSource = "$simplePath\build\app\outputs\flutter-apk\app-release.apk"
    $apkDest = "C:\Users\USER\Desktop\FreeTask-release.apk"
    
    if (Test-Path $apkSource) {
        Copy-Item $apkSource $apkDest -Force
        Write-Host "✓ APK copied to Desktop!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Location: $apkDest" -ForegroundColor Cyan
        
        $size = (Get-Item $apkDest).Length / 1MB
        Write-Host "Size: $([math]::Round($size, 2)) MB" -ForegroundColor White
        Write-Host ""
        Write-Host "You can also find it at:" -ForegroundColor Yellow
        Write-Host "  $apkSource" -ForegroundColor White
    }
} else {
    Write-Host "Build failed. Trying debug APK..." -ForegroundColor Red
    flutter build apk --debug
    
    if ($LASTEXITCODE -eq 0) {
        $apkSource = "$simplePath\build\app\outputs\flutter-apk\app-debug.apk"
        $apkDest = "C:\Users\USER\Desktop\FreeTask-debug.apk"
        
        Copy-Item $apkSource $apkDest -Force
        Write-Host ""
        Write-Host "✓ Debug APK created!" -ForegroundColor Green
        Write-Host "Location: $apkDest" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Cleanup: You can delete C:\freetask_build when done" -ForegroundColor DarkGray
Write-Host ""
# Exit explicitly
exit $LASTEXITCODE
