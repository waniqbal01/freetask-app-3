# ====================================================================
# FREETASK - Upload Keystore Generator for Play App Signing
# ====================================================================
# Script ini untuk generate UPLOAD keystore (bukan app signing key)
# Untuk digunakan dengan Google Play App Signing
# ====================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Generate Upload Keystore" -ForegroundColor Cyan
Write-Host "  For Google Play App Signing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration for UPLOAD KEY (not app signing key)
$keyAlias = "upload"
$keystoreName = "upload-keystore.jks"
$keystorePath = "app\$keystoreName"

# Certificate info
$cn = "Freetask Developer"
$ou = "Development"
$o = "Freetask"
$l = "Kuala Lumpur"
$s = "Selangor"
$c = "MY"

Write-Host "This will create an UPLOAD keystore for Google Play:" -ForegroundColor Yellow
Write-Host "  File: $keystorePath" -ForegroundColor Gray
Write-Host "  Alias: $keyAlias" -ForegroundColor Gray
Write-Host ""

# Prompt for password
Write-Host "Enter password for the keystore:" -ForegroundColor Cyan
$password = Read-Host "Password (min 6 characters)" -AsSecureString
$passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

if ($passwordPlain.Length -lt 6) {
    Write-Host ""
    Write-Host "[ERROR] Password must be at least 6 characters!" -ForegroundColor Red
    exit 1
}

# Find keytool
Write-Host ""
Write-Host "Finding keytool..." -ForegroundColor Yellow
$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
    $androidStudioJava = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $androidStudioJava) {
        $keytoolCmd = $androidStudioJava
    } else {
        Write-Host "[ERROR] keytool not found!" -ForegroundColor Red
        Write-Host "Please install Java or Android Studio." -ForegroundColor Yellow
        exit 1
    }
} else {
    $keytoolCmd = "$javaHome\bin\keytool.exe"
}

# Create app directory
if (-not (Test-Path "app")) {
    New-Item -ItemType Directory -Path "app" | Out-Null
}

# Generate keystore
$dname = "CN=$cn, OU=$ou, O=$o, L=$l, S=$s, C=$c"

Write-Host "Generating upload keystore..." -ForegroundColor Yellow
Write-Host ""

$process = Start-Process -FilePath $keytoolCmd -ArgumentList @(
    "-genkey",
    "-v",
    "-keystore", $keystorePath,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-alias", $keyAlias,
    "-storepass", $passwordPlain,
    "-keypass", $passwordPlain,
    "-dname", $dname
) -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "[OK] Upload keystore created!" -ForegroundColor Green
    Write-Host "     Location: $keystorePath" -ForegroundColor Gray
    
    # Create key.properties
    $keyPropertiesContent = @"
storePassword=$passwordPlain
keyPassword=$passwordPlain
keyAlias=$keyAlias
storeFile=$keystorePath
"@
    
    Set-Content -Path "key.properties" -Value $keyPropertiesContent -Encoding UTF8
    Write-Host "[OK] key.properties created!" -ForegroundColor Green
    
    # Export certificate
    Write-Host ""
    Write-Host "Exporting upload certificate..." -ForegroundColor Yellow
    
    $certPath = "upload_certificate.pem"
    $exportProcess = Start-Process -FilePath $keytoolCmd -ArgumentList @(
        "-export",
        "-rfc",
        "-keystore", $keystorePath,
        "-alias", $keyAlias,
        "-storepass", $passwordPlain,
        "-file", $certPath
    ) -NoNewWindow -Wait -PassThru
    
    if ($exportProcess.ExitCode -eq 0) {
        Write-Host "[OK] Certificate exported!" -ForegroundColor Green
        Write-Host "     Location: $certPath" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SUCCESS!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Cyan
    Write-Host "  1. $keystorePath (upload keystore)" -ForegroundColor White
    Write-Host "  2. key.properties (Flutter config)" -ForegroundColor White
    Write-Host "  3. $certPath (upload certificate)" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  NEXT STEPS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Step 1: Remove old app bundle di Play Console" -ForegroundColor Cyan
    Write-Host "  - Go to: Testing > Closed testing" -ForegroundColor White
    Write-Host "  - Remove app bundle yang error" -ForegroundColor White
    Write-Host ""
    Write-Host "Step 2: Verify Play App Signing" -ForegroundColor Cyan
    Write-Host "  - Go to: Setup > App integrity" -ForegroundColor White
    Write-Host "  - Confirm: 'App signing by Google Play' = ENABLED" -ForegroundColor White
    Write-Host ""
    Write-Host "Step 3: Upload certificate ke Play Console" -ForegroundColor Cyan
    Write-Host "  - Still in: Setup > App integrity" -ForegroundColor White
    Write-Host "  - Find: 'Upload key certificate' section" -ForegroundColor White
    Write-Host "  - Upload file: $certPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Step 4: Build app bundle" -ForegroundColor Cyan
    Write-Host "  - cd .." -ForegroundColor Gray
    Write-Host "  - flutter clean" -ForegroundColor Gray
    Write-Host "  - flutter build appbundle --release" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Step 5: Upload .aab ke Play Console" -ForegroundColor Cyan
    Write-Host "  - File: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Gray
    Write-Host "  - Upload to: Testing > Closed testing" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[IMPORTANT] Save your password: $passwordPlain" -ForegroundColor Yellow
    Write-Host "[IMPORTANT] Backup $keystorePath safely!" -ForegroundColor Yellow
    Write-Host ""
    
} else {
    Write-Host ""
    Write-Host "[ERROR] Failed to create keystore!" -ForegroundColor Red
    Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Red
    exit 1
}
