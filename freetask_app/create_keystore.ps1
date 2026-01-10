# ============================================
# Android Release Signing Setup Guide
# ============================================
# This guide will help you create a production keystore for your app

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Release Signing Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will guide you through creating a production keystore" -ForegroundColor Yellow
Write-Host "for signing your Android app for Google Play Console." -ForegroundColor Yellow
Write-Host ""

# Configuration
$keystoreName = "freetask-release-key.jks"
$keystorePath = "C:\Users\USER\freetask-app-3\freetask_app\android\app\$keystoreName"
$keyPropertiesPath = "C:\Users\USER\freetask-app-3\freetask_app\android\key.properties"

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "⚠ Keystore already exists at: $keystorePath" -ForegroundColor Yellow
    Write-Host ""
    $overwrite = Read-Host "Do you want to create a new keystore? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Exiting without creating new keystore." -ForegroundColor Gray
        exit 0
    }
}

Write-Host ""
Write-Host "Please provide the following information:" -ForegroundColor Cyan
Write-Host "(This information will be used to create your keystore)" -ForegroundColor Gray
Write-Host ""

# Gather information
$keyAlias = Read-Host "Key Alias (e.g., freetask-key)"
if ([string]::IsNullOrWhiteSpace($keyAlias)) {
    $keyAlias = "freetask-key"
    Write-Host "  Using default: $keyAlias" -ForegroundColor Gray
}

$storePassword = Read-Host "Store Password (minimum 6 characters)" -AsSecureString
$storePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))

$keyPassword = Read-Host "Key Password (minimum 6 characters)" -AsSecureString
$keyPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))

$validityYears = Read-Host "Validity in years (default: 25)"
if ([string]::IsNullOrWhiteSpace($validityYears)) {
    $validityYears = 25
}
$validityDays = [int]$validityYears * 365

Write-Host ""
Write-Host "Distinguished Name (DN) Information:" -ForegroundColor Cyan
$commonName = Read-Host "Your full name or organization (CN)"
$organizationalUnit = Read-Host "Organizational Unit (OU, e.g., Development Team)"
$organization = Read-Host "Organization (O, e.g., FreeTask)"
$city = Read-Host "City or Locality (L)"
$state = Read-Host "State or Province (ST)"
$countryCode = Read-Host "Country Code (C, e.g., MY for Malaysia)"

# Build DN string
$dn = "CN=$commonName, OU=$organizationalUnit, O=$organization, L=$city, ST=$state, C=$countryCode"

Write-Host ""
Write-Host "Creating keystore..." -ForegroundColor Yellow

# Find keytool (usually comes with Java)
$keytoolPath = "keytool"

# Generate keystore
try {
    $keytoolArgs = @(
        "-genkeypair"
        "-v"
        "-keystore", $keystorePath
        "-alias", $keyAlias
        "-keyalg", "RSA"
        "-keysize", "2048"
        "-validity", $validityDays
        "-storepass", $storePasswordPlain
        "-keypass", $keyPasswordPlain
        "-dname", $dn
    )
    
    & $keytoolPath $keytoolArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✓ Keystore created successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Create key.properties file
        Write-Host "Creating key.properties file..." -ForegroundColor Yellow
        $keyPropertiesContent = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=$keyAlias
storeFile=app/$keystoreName
"@
        
        Set-Content -Path $keyPropertiesPath -Value $keyPropertiesContent
        Write-Host "  ✓ key.properties created!" -ForegroundColor Green
        Write-Host ""
        
        # Show important information
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "IMPORTANT INFORMATION" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Keystore Location:" -ForegroundColor Cyan
        Write-Host "  $keystorePath" -ForegroundColor White
        Write-Host ""
        Write-Host "⚠ CRITICAL: BACKUP YOUR KEYSTORE!" -ForegroundColor Red
        Write-Host "  If you lose this keystore, you CANNOT update your app on Google Play!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Store the following information securely:" -ForegroundColor Yellow
        Write-Host "  Key Alias: $keyAlias" -ForegroundColor White
        Write-Host "  Store Password: ********" -ForegroundColor White
        Write-Host "  Key Password: ********" -ForegroundColor White
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Backup your keystore to a secure location" -ForegroundColor White
        Write-Host "  2. The build.gradle.kts will be updated automatically" -ForegroundColor White
        Write-Host "  3. Build your release APK with: flutter build apk --release" -ForegroundColor White
        Write-Host ""
        
        # Ask to update build.gradle.kts
        Write-Host "Do you want to update build.gradle.kts now? (yes/no)" -ForegroundColor Cyan
        $updateGradle = Read-Host
        
        if ($updateGradle -eq "yes") {
            Write-Host ""
            Write-Host "Updating build.gradle.kts..." -ForegroundColor Yellow
            # This will be done in the next script
            Write-Host "  ℹ Please run update_gradle_signing.ps1" -ForegroundColor Gray
        }
        
    } else {
        Write-Host ""
        Write-Host "  ✗ Failed to create keystore" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host "  ✗ Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure Java JDK is installed and keytool is in your PATH" -ForegroundColor Yellow
    exit 1
}
