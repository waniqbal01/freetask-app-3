# ====================================================================
# FREETASK - Quick Keystore Generator (Non-Interactive)
# ====================================================================
# This script generates a new keystore with default values
# Usage: .\generate_keystore.ps1
# ====================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FREETASK - Quick Keystore Generator  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration with default values
$keyAlias = "freetask-key"
$keystoreName = "freetask-release-key.jks"
$keystorePath = "app\$keystoreName"

# Default certificate information
$cn = "Freetask Developer"
$ou = "Development"
$o = "Freetask"
$l = "Kuala Lumpur"
$s = "Selangor"
$c = "MY"

Write-Host "This script will generate a NEW keystore with the following details:" -ForegroundColor Yellow
Write-Host "  Key Alias: $keyAlias" -ForegroundColor Gray
Write-Host "  Keystore File: $keystorePath" -ForegroundColor Gray
Write-Host "  Organization: $o" -ForegroundColor Gray
Write-Host ""

# Prompt for passwords only
Write-Host "Please provide passwords (you can change these later):" -ForegroundColor Cyan
$storePassword = Read-Host "Keystore Password (min 6 characters)" -AsSecureString
$keyPassword = Read-Host "Key Password (min 6 characters, can be same as keystore password)" -AsSecureString

# Convert SecureString to plain text
$storePasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))
$keyPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))

# Validate password length
if ($storePasswordPlain.Length -lt 6 -or $keyPasswordPlain.Length -lt 6) {
    Write-Host ""
    Write-Host "[ERROR] Passwords must be at least 6 characters long!" -ForegroundColor Red
    exit 1
}

# Find keytool
Write-Host ""
Write-Host "Finding keytool..." -ForegroundColor Yellow
$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
    # Try to find Java from Android Studio
    $androidStudioJava = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $androidStudioJava) {
        $keytoolCmd = $androidStudioJava
        Write-Host "Using Android Studio JDK: $keytoolCmd" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "[ERROR] Could not find keytool!" -ForegroundColor Red
        Write-Host "Please install Java or set JAVA_HOME environment variable." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Alternative: Install Android Studio which includes Java." -ForegroundColor Yellow
        exit 1
    }
} else {
    $keytoolCmd = "$javaHome\bin\keytool.exe"
    Write-Host "Using JAVA_HOME: $keytoolCmd" -ForegroundColor Gray
}

# Create app directory if not exists
if (-not (Test-Path "app")) {
    New-Item -ItemType Directory -Path "app" | Out-Null
}

# Generate keystore
$dname = "CN=$cn, OU=$ou, O=$o, L=$l, S=$s, C=$c"

Write-Host ""
Write-Host "Generating keystore..." -ForegroundColor Yellow
Write-Host "This may take a moment..." -ForegroundColor Gray
Write-Host ""

$arguments = @(
    "-genkeypair",
    "-v",
    "-keystore", $keystorePath,
    "-alias", $keyAlias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-storepass", $storePasswordPlain,
    "-keypass", $keyPasswordPlain,
    "-dname", $dname
)

$process = Start-Process -FilePath $keytoolCmd -ArgumentList $arguments -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "[OK] Keystore created successfully!" -ForegroundColor Green
    Write-Host "     Location: $keystorePath" -ForegroundColor Gray
    
    # Create key.properties
    $keyPropertiesContent = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=$keyAlias
storeFile=$keystorePath
"@
    
    Set-Content -Path "key.properties" -Value $keyPropertiesContent -Encoding UTF8
    Write-Host "[OK] key.properties created successfully!" -ForegroundColor Green
    
    # Display certificate fingerprint
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Certificate Fingerprints" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $certInfo = & $keytoolCmd -list -v -keystore $keystorePath -storepass $storePasswordPlain 2>&1
    $sha1 = $certInfo | Select-String -Pattern "SHA1:" | ForEach-Object { $_.ToString().Trim() }
    $sha256 = $certInfo | Select-String -Pattern "SHA256:" | ForEach-Object { $_.ToString().Trim() }
    
    if ($sha1) { Write-Host $sha1 -ForegroundColor White }
    if ($sha256) { Write-Host $sha256 -ForegroundColor White }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  IMPORTANT - NEXT STEPS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This is a NEW keystore. Since your app was previously uploaded" -ForegroundColor White
    Write-Host "with a different key, you MUST enroll in Play App Signing." -ForegroundColor White
    Write-Host ""
    Write-Host "STEP 1: Export Upload Certificate" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Run this command to export the certificate:" -ForegroundColor White
    Write-Host ""
    Write-Host "  keytool -export -rfc -keystore $keystorePath ``" -ForegroundColor Gray
    Write-Host "    -alias $keyAlias ``" -ForegroundColor Gray
    Write-Host "    -file upload_cert.pem" -ForegroundColor Gray
    Write-Host ""
    Write-Host "STEP 2: Setup Google Play App Signing" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Go to: https://play.google.com/console" -ForegroundColor White
    Write-Host "  2. Select your Freetask app" -ForegroundColor White  
    Write-Host "  3. Go to: Setup > App Signing" -ForegroundColor White
    Write-Host "  4. Choose 'Use Google-generated key' or 'Upgrade'" -ForegroundColor White
    Write-Host "  5. Upload the upload_cert.pem file" -ForegroundColor White
    Write-Host "  6. Google will handle the final app signing" -ForegroundColor White
    Write-Host ""
    Write-Host "STEP 3: Build and Upload" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  cd .." -ForegroundColor Gray
    Write-Host "  flutter clean" -ForegroundColor Gray
    Write-Host "  flutter build appbundle --release" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Upload: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[SUCCESS] Keystore setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "SECURITY REMINDER:" -ForegroundColor Red
    Write-Host "  - NEVER commit key.properties or *.jks to git" -ForegroundColor Yellow
    Write-Host "  - BACKUP your keystore and passwords safely" -ForegroundColor Yellow
    Write-Host "  - Losing the keystore means you cannot update your app!" -ForegroundColor Yellow
    Write-Host ""
    
} else {
    Write-Host ""
    Write-Host "[ERROR] Failed to create keystore!" -ForegroundColor Red
    Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - Password too short (must be 6+ characters)" -ForegroundColor White
    Write-Host "  - Keystore file already exists (delete it first)" -ForegroundColor White
    Write-Host "  - Insufficient permissions" -ForegroundColor White
    exit 1
}
