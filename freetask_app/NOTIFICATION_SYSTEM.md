# Notification System Documentation

## Overview
FreeTask app sekarang dilengkapi dengan sistem notifikasi yang tampil di pojok kanan atas layar dengan animasi smooth dan desain modern.

## Fitur
- ✅ Notifikasi muncul di pojok kanan atas
- ✅ 4 tipe notifikasi: Success, Error, Warning, Info
- ✅ Animasi slide dan fade yang smooth
- ✅ Support antrian notifikasi (queue)
- ✅ Auto-dismiss setelah durasi tertentu
- ✅ Tombol close manual
- ✅ Design modern dengan shadow dan colored indicator

## Cara Penggunaan

### Import
```dart
import 'package:freetask_app/core/notifications/notification_service.dart';
import 'package:freetask_app/core/notifications/notification_overlay.dart';
```

### Tipe Notifikasi

#### 1. Success Notification (Hijau)
```dart
notificationService.showSuccess(
  'Berhasil!',
  'Data berhasil disimpan',
);
```

#### 2. Error Notification (Merah)
```dart
notificationService.showError(
  'Error!',
  'Terjadi kesalahan saat menyimpan data',
);
```

#### 3. Warning Notification (Orange)
```dart
notificationService.showWarning(
  'Perhatian!',
  'Beberapa field belum diisi',
);
```

#### 4. Info Notification (Biru)
```dart
notificationService.showInfo(
  'Info',
  'Notifikasi baru tersedia',
);
```

### Custom Duration
```dart
notificationService.showSuccess(
  'Success!',
  'Operasi selesai',
  duration: Duration(seconds: 5), // Custom duration
);
```

### Manual Method dengan Tipe
```dart
notificationService.pushLocal(
  'Custom Title',
  'Custom message',
  type: NotificationType.success,
  duration: Duration(seconds: 5),
);
```

## Contoh Implementasi

### Dalam Screen/Widget
```dart
class MyScreen extends StatelessWidget {
  void _saveData() async {
    try {
      // Proses saving...
      await saveToDatabase();
      
      // Tampilkan success notification
      notificationService.showSuccess(
        'Berhasil!',
        'Data berhasil disimpan',
      );
    } catch (e) {
      // Tampilkan error notification
      notificationService.showError(
        'Gagal!',
        'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: _saveData,
        child: Text('Save'),
      ),
    );
  }
}
```

### Dalam Repository/Service
```dart
class UserRepository {
  Future<void> updateProfile(UserData data) async {
    try {
      final response = await api.post('/profile', data: data.toJson());
      
      if (response.statusCode == 200) {
        notificationService.showSuccess(
          'Profile Updated',
          'Your profile has been updated successfully',
        );
      } else {
        notificationService.showWarning(
          'Partial Success',
          'Some data might not be saved',
        );
      }
    } catch (e) {
      notificationService.showError(
        'Update Failed',
        'Could not update profile: ${e.toString()}',
      );
      rethrow;
    }
  }
}
```

## Design Specifications

### Colors
- **Success**: `#10B981` (Green)
- **Error**: `#EF4444` (Red)  
- **Warning**: `#F59E0B` (Amber)
- **Info**: `#3B82F6` (Blue)

### Animations
- **Entry**: Slide dari kanan dengan fade in (400ms, easeOutCubic)
- **Exit**: Reverse animation (400ms)

### Layout
- **Position**: Top-right corner, 16px dari tepi
- **Width**: 320px - 380px
- **Shadow**: 20px blur dengan opacity 0.1
- **Border Radius**: 12px
- **Color Indicator**: 5px bar di sisi kiri

## Demo Screen

Untuk melihat demo lengkap, jalankan:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationDemoScreen(),
  ),
);
```

Demo screen menyediakan:
- Tombol untuk setiap tipe notifikasi
- Test queue dengan 3 notifikasi sekaligus
- Contoh implementasi lengkap

## Queue System

Sistem notifikasi memiliki built-in queue. Jika ada notifikasi yang sedang tampil, notifikasi berikutnya akan masuk antrian dan ditampilkan setelah notifikasi sebelumnya selesai.

```dart
// Semua akan ditampilkan secara berurutan
notificationService.showSuccess('First', 'Message 1');
notificationService.showInfo('Second', 'Message 2');
notificationService.showWarning('Third', 'Message 3');
```

## Fallback

Jika context belum tersedia (rare case), sistem akan fallback ke SnackBar default.

## Migration dari SnackBar

Untuk mengupdate code lama yang menggunakan SnackBar:

### Before
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Success')),
);
```

### After
```dart
notificationService.showSuccess(
  'Success',
  'Operation completed',
);
```
