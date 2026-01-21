# ====================================================================
# FREETASK - Android Keystore Setup Script
# ====================================================================
# This script helps you setup Android signing for production releases
# ====================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FREETASK - Keystore Setup Assistant  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Search for existing keystore
Write-Host "Step 1: Searching for existing keystore files..." -ForegroundColor Yellow
Write-Host ""

$commonLocations = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "C:\Users\$env:USERNAME",
    (Get-Location).Path
)

$foundKeystores = @()

Write-Host "Searching in common locations..." -ForegroundColor Gray
foreach ($location in $commonLocations) {
    if (Test-Path $location) {
        $jksFiles = Get-ChildItem -Path $location -Filter "*.jks" -File -Recurse -ErrorAction SilentlyContinue -Depth 3
        $keystoreFiles = Get-ChildItem -Path $location -Filter "*.keystore" -File -Recurse -ErrorAction SilentlyContinue -Depth 3
        
        $foundKeystores += $jksFiles
        $foundKeystores += $keystoreFiles
    }
}

if ($foundKeystores.Count -gt 0) {
    Write-Host "Found $($foundKeystores.Count) keystore file(s):" -ForegroundColor Green
    for ($i = 0; $i -lt $foundKeystores.Count; $i++) {
        Write-Host "  [$i] $($foundKeystores[$i].FullName)" -ForegroundColor White
        Write-Host "      Modified: $($foundKeystores[$i].LastWriteTime)" -ForegroundColor Gray
    }
    Write-Host ""
    
    $choice = Read-Host "Enter number of the keystore to use (or press Enter to create new)"
    
    if ($choice -match '^\d+$' -and [int]$choice -lt $foundKeystores.Count) {
        $selectedKeystore = $foundKeystores[[int]$choice]
        Write-Host "Selected: $($selectedKeystore.FullName)" -ForegroundColor Green
        
        # Copy to android/app directory
        $destPath = "app\$($selectedKeystore.Name)"
        Copy-Item -Path $selectedKeystore.FullName -Destination $destPath -Force
        Write-Host "Copied keystore to: $destPath" -ForegroundColor Green
        
        # Ask for keystore details
        Write-Host ""
        Write-Host "Please provide keystore details:" -ForegroundColor Yellow
        $keyAlias = Read-Host "Key Alias (e.g., freetask-key)"
        $storePassword = Read-Host "Store Password" -AsSecureString
        $keyPassword = Read-Host "Key Password" -AsSecureString
        
        # Convert SecureString to plain text for properties file
        $storePasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))
        $keyPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))
        
        # Create key.properties
        $keyPropertiesContent = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=$keyAlias
storeFile=$destPath
"@
        
        Set-Content -Path "key.properties" -Value $keyPropertiesContent
        Write-Host ""
        Write-Host "[OK] key.properties created successfully!" -ForegroundColor Green
        
        # Verify keystore
        Write-Host ""
        Write-Host "Verifying keystore fingerprint..." -ForegroundColor Yellow
        $javaHome = $env:JAVA_HOME
        if (-not $javaHome) {
            # Try to find Java from Android Studio
            $androidStudioJava = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
            if (Test-Path $androidStudioJava) {
                $keytoolCmd = $androidStudioJava
            } else {
                $keytoolCmd = "keytool"
            }
        } else {
            $keytoolCmd = "$javaHome\bin\keytool.exe"
        }
        
        Write-Host "Running: $keytoolCmd -list -v -keystore $destPath" -ForegroundColor Gray
        Write-Host "You will need to enter your store password again" -ForegroundColor Gray
        & $keytoolCmd -list -v -keystore $destPath
        
        Write-Host ""
        Write-Host "[OK] Setup complete! You can now build your app bundle." -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Check if the SHA1 fingerprint above matches Google Play Console" -ForegroundColor White
        Write-Host "2. If it matches, run: flutter build appbundle --release" -ForegroundColor White
        Write-Host "3. If it DOESN'T match, you may need to enroll in Play App Signing" -ForegroundColor White
        
        exit 0
    }
}

Write-Host "No existing keystore found or user chose to create new." -ForegroundColor Yellow
Write-Host ""

# Step 2: Create new keystore
Write-Host "Step 2: Creating a NEW keystore..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Please provide the following information:" -ForegroundColor Cyan

$keyAlias = "freetask-key"
$keystoreName = "freetask-release-key.jks"

Write-Host "Key Alias: $keyAlias (default)" -ForegroundColor Gray
Write-Host "Keystore Name: $keystoreName (default)" -ForegroundColor Gray
Write-Host ""

$cn = Read-Host "Your Name (CN)"
$ou = Read-Host "Organizational Unit (OU, e.g., Development)"
$o = Read-Host "Organization (O, e.g., Freetask)"
$l = Read-Host "City/Locality (L)"
$s = Read-Host "State/Province (S)"
$c = Read-Host "Country Code (C, 2 letters, e.g., MY)"

Write-Host ""
$storePassword = Read-Host "Keystore Password (min 6 characters)" -AsSecureString
$keyPassword = Read-Host "Key Password (min 6 characters)" -AsSecureString

# Convert SecureString to plain text
$storePasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))
$keyPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))

# Find keytool
$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
    # Try to find Java from Android Studio
    $androidStudioJava = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $androidStudioJava) {
        $keytoolCmd = $androidStudioJava
    } else {
        Write-Host ""
        Write-Host "ERROR: Could not find keytool. Please install Java or set JAVA_HOME environment variable." -ForegroundColor Red
        exit 1
    }
} else {
    $keytoolCmd = "$javaHome\bin\keytool.exe"
}

# Generate keystore
$dname = "CN=$cn, OU=$ou, O=$o, L=$l, S=$s, C=$c"
$keystorePath = "app\$keystoreName"

Write-Host ""
Write-Host "Generating keystore..." -ForegroundColor Yellow
Write-Host "This may take a moment..." -ForegroundColor Gray

$process = Start-Process -FilePath $keytoolCmd -ArgumentList @(
    "-genkeypair",
    "-v",
    "-keystore", $keystorePath,
    "-alias", $keyAlias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-storepass", $storePasswordPlain,
    "-keypass", $keyPasswordPlain,
    "-dname", "`"$dname`""
) -NoNewWindow -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "[OK] Keystore created successfully!" -ForegroundColor Green
    
    # Create key.properties
    $keyPropertiesContent = @"
storePassword=$storePasswordPlain
keyPassword=$keyPasswordPlain
keyAlias=$keyAlias
storeFile=$keystorePath
"@
    
    Set-Content -Path "key.properties" -Value $keyPropertiesContent
    Write-Host "[OK] key.properties created successfully!" -ForegroundColor Green
    
    # Display certificate fingerprint
    Write-Host ""
    Write-Host "Certificate Information:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    & $keytoolCmd -list -v -keystore $keystorePath -storepass $storePasswordPlain | Select-String -Pattern "SHA1:|SHA256:"
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  IMPORTANT - NEXT STEPS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "This is a NEW keystore. Since your app was previously uploaded with" -ForegroundColor Yellow
    Write-Host "a different key, you have 2 options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OPTION A (RECOMMENDED): Enroll in Play App Signing" -ForegroundColor Cyan
    Write-Host "  1. Go to Google Play Console > Setup > App Signing" -ForegroundColor White
    Write-Host "  2. Choose 'Enroll in Play App Signing'" -ForegroundColor White
    Write-Host "  3. Export upload certificate with command below:" -ForegroundColor White
    Write-Host "     keytool -export -rfc -keystore $keystorePath -alias $keyAlias -file upload_cert.pem" -ForegroundColor Gray
    Write-Host "  4. Upload the upload_cert.pem to Play Console" -ForegroundColor White
    Write-Host "  5. Google will re-sign your app with their key" -ForegroundColor White
    Write-Host ""
    Write-Host "OPTION B: Contact Google Support" -ForegroundColor Cyan
    Write-Host "  - Request to reset signing key (can take several days)" -ForegroundColor White
    Write-Host ""
    Write-Host "After completing either option, build your app bundle:" -ForegroundColor Yellow
    Write-Host "  cd .." -ForegroundColor Gray
    Write-Host "  flutter build appbundle --release" -ForegroundColor Gray
    Write-Host ""
    
} else {
    Write-Host "[ERROR] Failed to create keystore. Exit code: $($process.ExitCode)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "SECURITY REMINDER:" -ForegroundColor Red
Write-Host "  - NEVER commit key.properties or *.jks files to git!" -ForegroundColor Yellow
Write-Host "  - Keep your keystore file and passwords in a safe place!" -ForegroundColor Yellow
Write-Host "  - Backup your keystore - losing it means you cannot update your app!" -ForegroundColor Yellow
Write-Host ""
