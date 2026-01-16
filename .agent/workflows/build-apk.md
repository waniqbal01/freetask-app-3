---
description: Build APK untuk aplikasi Freetask
---

# Build APK - Freetask App

Panduan untuk membuat APK untuk testing atau distribusi aplikasi Freetask.

## Prasyarat

1. Flutter SDK sudah terinstall
2. Android SDK dan tools sudah dikonfigurasi
3. Berada di folder root project

## Opsi 1: Build Debug APK (Untuk Testing)

Debug APK cocok untuk testing internal, instalasi cepat, dan debugging. Menggunakan debug signing yang sudah tersedia otomatis.

### Langkah-langkah:

1. Masuk ke folder Flutter app:
```powershell
cd freetask_app
```

// turbo
2. Clean build sebelumnya (opsional tapi direkomendasikan):
```powershell
flutter clean
```

// turbo
3. Get dependencies:
```powershell
flutter pub get
```

// turbo
4. Build debug APK:
```powershell
flutter build apk --debug
```

### Lokasi Output:
APK akan berada di: `freetask_app\build\app\outputs\flutter-apk\app-debug.apk`

**Ukuran file:** Biasanya lebih besar (~40-60MB) karena berisi debugging symbols

---

## Opsi 2: Build Release APK (Untuk Distribusi)

Release APK adalah build yang dioptimasi untuk production/distribusi. Lebih kecil dan lebih cepat.

### Langkah-langkah:

1. Masuk ke folder Flutter app:
```powershell
cd freetask_app
```

// turbo
2. Clean build sebelumnya:
```powershell
flutter clean
```

// turbo
3. Get dependencies:
```powershell
flutter pub get
```

// turbo
4. Build release APK:
```powershell
flutter build apk --release
```

### Lokasi Output:
APK akan berada di: `freetask_app\build\app\outputs\flutter-apk\app-release.apk`

**Ukuran file:** Lebih kecil (~20-30MB) karena sudah dioptimasi dan di-obfuscate

### Catatan Signing:

- **Jika `key.properties` ADA:** APK akan di-sign dengan release keystore Anda (siap untuk Google Play Store)
- **Jika `key.properties` TIDAK ADA:** APK akan di-sign dengan debug key (untuk distribusi internal saja, TIDAK bisa di-upload ke Play Store)

Untuk membuat keystore production, lihat file `create_keystore.ps1` di folder android atau hubungi tim.

---

## Opsi 3: Build Split APKs per ABI (Ukuran Lebih Kecil)

Membuat APK terpisah untuk setiap arsitektur processor (arm64-v8a, armeabi-v7a, x86_64). Ukuran per APK lebih kecil.

// turbo
```powershell
cd freetask_app
flutter build apk --release --split-per-abi
```

### Lokasi Output:
Multiple APK files di `freetask_app\build\app\outputs\flutter-apk\`:
- `app-arm64-v8a-release.apk` (~15-20MB) - Untuk device modern (recommended)
- `app-armeabi-v7a-release.apk` (~15-20MB) - Untuk device lama
- `app-x86_64-release.apk` (~15-20MB) - Untuk emulator/tablet Intel

**Gunakan opsi ini jika:** Ingin ukuran maksimal kecil untuk distribusi manual. Google Play Store otomatis melakukan ini.

---

## Testing APK

### Install di Device Fisik:

1. Enable USB Debugging di Android device
2. Sambungkan device via USB
3. Install APK:
```powershell
# Debug APK
flutter install

# Atau manual dengan adb
adb install freetask_app\build\app\outputs\flutter-apk\app-debug.apk
```

### Install di Emulator:

Drag and drop file APK ke emulator window, atau gunakan command adb di atas.

---

## Troubleshooting

### Error: "Gradle build failed"

**Solusi:**
```powershell
cd freetask_app\android
.\gradlew clean
cd ..\..
flutter clean
flutter pub get
flutter build apk --release
```

### Error: "SDK location not found"

**Solusi:** Set environment variable ANDROID_HOME:
```powershell
$env:ANDROID_HOME = "C:\Users\YOUR_USER\AppData\Local\Android\Sdk"
```

### APK terlalu besar

**Solusi:**
1. Gunakan `--split-per-abi` option
2. Gunakan `--release` bukan `--debug`
3. Enable code shrinking (sudah default di release builds)

### Error Firebase atau Dependencies

**Solusi:**
```powershell
cd freetask_app
flutter pub get
flutter pub upgrade
```

---

## Informasi Build

- **Package Name:** com.freetask.apps
- **Version:** 1.0.0+1 (dari pubspec.yaml)
- **Min SDK:** Flutter default (check flutter.minSdkVersion)
- **Target SDK:** Flutter default (check flutter.targetSdkVersion)

## File Penting

- Build config: `freetask_app\android\app\build.gradle.kts`
- App config: `freetask_app\pubspec.yaml`
- Signing template: `freetask_app\android\key.properties.template`
