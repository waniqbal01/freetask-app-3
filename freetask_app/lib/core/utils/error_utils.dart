import 'package:dio/dio.dart';

String resolveDioErrorMessage(
  DioException error, {
  String fallback = 'Ralat rangkaian berlaku. Sila cuba lagi.',
}) {
  final responseData = error.response?.data;

  if (responseData is Map<String, dynamic>) {
    final message = responseData['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
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
