import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

String resolveDioErrorMessage(
  DioException error, {
  String fallback = 'Ralat rangkaian berlaku. Sila cuba lagi.',
}) {
  final statusCode = error.response?.statusCode;
  final path = error.requestOptions.path;

  // Network/connection errors (no response from server)
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.unknown) {
    return 'Tidak dapat hubungi server. Sila semak:\n'
        '1. Backend API sedang berjalan?\n'
        '2. URL API betul? (Semak "Tukar API Server")\n'
        '3. CORS configuration betul? (untuk Web)';
  }

  // Timeout errors - UX-G-03: Enhanced message
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'Sambungan internet bermasalah. Sila periksa rangkaian anda.';
  }

  // HTTP error responses (server responded with error)
  if (statusCode == 401 && path.contains('/auth/login')) {
    return 'Email atau kata laluan salah.';
  }

  // Try to extract backend error message first to provide specific feedback
  final responseData = error.response?.data;
  if (responseData is Map<String, dynamic>) {
    final message = responseData['message'];
    if (message is String && message.trim().isNotEmpty) {
      // If it's a generic 401 or 404, we might still want local fallback, but explicit backend text wins
      if (!(statusCode == 401 && message == 'Unauthorized')) {
        return message.trim();
      }
    }
    if (message is List) {
      final joined = message
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .join('\n');
      if (joined.isNotEmpty) {
        return joined;
      }
    }
  }

  // UX-G-03: Enhanced error messages for common status codes
  if (statusCode == 401) {
    return 'Sesi anda tamat. Sila login semula.';
  }

  if (statusCode == 409) {
    // Check if it's a registration conflict
    if (path.contains('/auth/register')) {
      return 'Email ini sudah berdaftar. Sila log masuk.';
    }
    // Generic conflict message
    return 'Tindakan ini tidak dibenarkan dalam status semasa. Sila refresh dan cuba lagi.';
  }

  if (statusCode == 400) {
    return 'Sila semak semula maklumat yang diisi.';
  }

  if (statusCode == 403) {
    return 'Anda tidak mempunyai kebenaran untuk tindakan ini.';
  }

  if (statusCode == 404) {
    return 'Sumber yang diminta tidak dijumpai.';
  }

  if (statusCode != null && statusCode >= 500) {
    final endpoint = path.isNotEmpty ? ' ($path)' : '';
    // Log detailed error for debugging
    debugPrint('🔴 SERVER ERROR $statusCode$endpoint');
    debugPrint('Response: ${error.response?.data}');
    debugPrint('Message: ${error.message}');
    return 'Ralat pelayan$endpoint. Sila cuba sebentar lagi atau hubungi sokongan.';
  }

  // Fallback to error message from Dio
  final message = error.message;
  if (message != null && message.trim().isNotEmpty) {
    return message.trim();
  }

  final statusMessage = error.response?.statusMessage;
  if (statusMessage != null && statusMessage.trim().isNotEmpty) {
    return statusMessage.trim();
  }

  return fallback;
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
    ),
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.blueGrey.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
