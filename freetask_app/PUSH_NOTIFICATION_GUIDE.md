# 📱 Panduan Push Notification — FreeTask

## Overview
Push notification bermakna notifikasi keluar di phone walaupun app ditutup.
Ini menggunakan **Firebase Cloud Messaging (FCM)**.

---

## Langkah 1: Cipta Firebase Project

1. Pergi ke [https://console.firebase.google.com](https://console.firebase.google.com)
2. Klik **"Add Project"**
3. Namakan projek, contoh: `freetask-prod`
4. Disable Google Analytics (tidak perlu untuk push notif)
5. Klik **"Create Project"**

---

## Langkah 2: Tambah Android App ke Firebase

1. Dalam Firebase Console → klik ikon **Android** (➕ Add App)
2. **Package name**: `com.example.freetask_app`
   - Semak nilai sebenar dalam `android/app/build.gradle` → `applicationId`
3. **App nickname**: FreeTask
4. Click **Register App**
5. Download `google-services.json`
6. Salin fail ke: `freetask_app/android/app/google-services.json`

---

## Langkah 3: Konfigurasi Android Build Files

### `android/build.gradle`
```gradle
buildscript {
  dependencies {
    // Tambah baris ini:
    classpath 'com.google.gms:google-services:4.4.0'
  }
}
```

### `android/app/build.gradle`
```gradle
// Di bahagian PALING BAWAH fail:
apply plugin: 'com.google.gms.google-services'
```

---

## Langkah 4: Tambah Flutter Package

```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```

---

## Langkah 5: Konfigurasi main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background handler — MESTI di luar class, top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Show notification when app is in background/killed
  print('Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}
```

---

## Langkah 6: Setup FCM dalam App (dalam AuthRepository atau main wrapper)

```dart
class FCMService {
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS mainly, Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token and register with backend
      final token = await messaging.getToken();
      if (token != null) {
        await notificationsRepository.registerToken(token, platform: 'android');
      }

      // Refresh token listener
      messaging.onTokenRefresh.listen((newToken) {
        notificationsRepository.registerToken(newToken, platform: 'android');
      });

      // Handle notification when app is OPEN (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Show local notification because FCM won't show heads-up when app is open
        _showLocalNotification(message);
      });

      // Handle when user TAPS notification (app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final chatId = message.data['conversationId'];
        if (chatId != null) {
          appRouter.push('/chats/$chatId/messages');
        }
      });
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    await localNotif.show(
      0,
      message.notification?.title ?? 'FreeTask',
      message.notification?.body ?? 'Mesej baru',
      const NotificationDetails(android: androidDetails),
    );
  }
}
```

---

## Langkah 7: Panggil FCMService.initialize()

Dalam `main.dart` selepas Firebase.initializeApp():

```dart
await FCMService.initialize();
```

---

## Langkah 8: Backend — Hantar FCM Notification

Backend sudah ada logic FCM dalam `notifications.service.ts`.
Pastikan Firebase Admin SDK didaftarkan dalam backend.

### `freetask-api/src/main.ts` atau `app.module.ts`:
```typescript
import * as admin from 'firebase-admin';

// Tambah di bootstrap/initialization
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    // OR guna service account:
    // credential: admin.credential.cert(serviceAccountJson),
  });
}
```

### Download Service Account Key:
1. Firebase Console → Project Settings → Service Accounts
2. Klik **"Generate New Private Key"**
3. Simpan JSON dan rujuk dalam backend (jangan commit ke Git!)

---

## Ringkasan Aliran Push Notification

```
User B hantar mesej
    → Backend: chats.service.postMessage()
    → Backend: chatGateway.emitNewMessage()
    → Backend: notificationsService.sendNotification() [FCM]
    → Phone User A terima push notification walaupun app ditutup
    → User A ketuk notifikasi → buka chat yang berkaitan
```

---

## ⚠️ Penting

- `google-services.json` JANGAN commit ke GitHub (tambah ke `.gitignore`)
- Firebase Service Account JSON JANGAN commit ke GitHub
- Test pada device sebenar (emulator kadang tak support FCM)
