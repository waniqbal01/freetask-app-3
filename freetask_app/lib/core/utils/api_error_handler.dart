import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../notifications/notification_service.dart';
import '../router.dart';
import '../../features/auth/auth_repository.dart';

Future<void> handleApiError(
  DioException error, {
  String forbiddenMessage = 'Anda tiada akses untuk tindakan ini.',
  GoRouter? router,
}) async {
  final status = error.response?.statusCode;
  if (status == 401) {
    notificationService.messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesi tamat. Sila log masuk semula.')),
    );
    await authRepository.logout();
    authRefreshNotifier.value = DateTime.now();
    (router ?? appRouter).go('/login');
    return;
  }

  if (status == 403) {
    notificationService.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(forbiddenMessage)),
    );
  }
}
