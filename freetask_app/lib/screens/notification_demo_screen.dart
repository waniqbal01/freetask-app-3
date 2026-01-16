import 'package:flutter/material.dart';
import '../core/notifications/notification_service.dart';

/// Demo widget to showcase the notification system
///
/// Example usage in any screen:
/// ```dart
/// // Success notification
/// notificationService.showSuccess(
///   'Berhasil!',
///   'Data berhasil disimpan',
/// );
///
/// // Error notification
/// notificationService.showError(
///   'Error!',
///   'Terjadi kesalahan saat menyimpan data',
/// );
///
/// // Warning notification
/// notificationService.showWarning(
///   'Perhatian!',
///   'Beberapa field belum diisi',
/// );
///
/// // Info notification (default)
/// notificationService.showInfo(
///   'Info',
///   'Notifikasi baru tersedia',
/// );
///
/// // Or use the base method with custom type and duration
/// notificationService.pushLocal(
///   'Custom',
///   'Pesan custom dengan durasi',
///   type: NotificationType.success,
///   duration: Duration(seconds: 5),
/// );
/// ```
class NotificationDemoScreen extends StatelessWidget {
  const NotificationDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Notifikasi'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tekan tombol untuk melihat notifikasi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  notificationService.showSuccess(
                    'Berhasil!',
                    'Operasi berhasil dilakukan',
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Success Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  notificationService.showError(
                    'Error!',
                    'Terjadi kesalahan saat memproses data',
                  );
                },
                icon: const Icon(Icons.error),
                label: const Text('Error Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  notificationService.showWarning(
                    'Perhatian!',
                    'Beberapa field belum diisi dengan lengkap',
                  );
                },
                icon: const Icon(Icons.warning),
                label: const Text('Warning Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  notificationService.showInfo(
                    'Info',
                    'Ada pembaruan baru tersedia untuk aplikasi',
                  );
                },
                icon: const Icon(Icons.info),
                label: const Text('Info Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: () {
                  // Test multiple notifications in queue
                  notificationService.showSuccess(
                      'Notifikasi 1', 'Pesan pertama');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    notificationService.showInfo('Notifikasi 2', 'Pesan kedua');
                  });
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    notificationService.showWarning(
                        'Notifikasi 3', 'Pesan ketiga');
                  });
                },
                icon: const Icon(Icons.queue),
                label: const Text('Test Queue (3 notifikasi)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
