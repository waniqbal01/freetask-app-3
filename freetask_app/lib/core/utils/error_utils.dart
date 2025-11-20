import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

enum AppErrorType {
  network,
  unauthorized,
  conflict,
  validation,
  forbidden,
  notFound,
  server,
  unknown,
}

class AppException implements Exception {
  const AppException(
    this.message, {
    this.type = AppErrorType.unknown,
    this.statusCode,
  });

  final String message;
  final AppErrorType type;
  final int? statusCode;

  bool get isUnauthorized => type == AppErrorType.unauthorized;
  bool get isNetworkError => type == AppErrorType.network;
}

AppException mapDioError(
  DioException error, {
  String fallback = 'Ralat rangkaian berlaku. Sila cuba lagi.',
}) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const AppException(
      'Tiada sambungan internet. Sila semak rangkaian anda.',
      type: AppErrorType.network,
    );
  }

  final statusCode = error.response?.statusCode;
  final data = error.response?.data;
  final messageFromServer = _extractMessage(data);

  if (statusCode == 0 || statusCode == null) {
    return AppException(messageFromServer ?? fallback, type: AppErrorType.unknown);
  }

  switch (statusCode) {
    case 400:
      return AppException(
        messageFromServer ?? 'Sila semak semula maklumat yang diisi.',
        type: AppErrorType.validation,
        statusCode: statusCode,
      );
    case 401:
      return AppException(
        messageFromServer ?? 'Sesi tamat. Sila log masuk semula.',
        type: AppErrorType.unauthorized,
        statusCode: statusCode,
      );
    case 409:
      return AppException(
        messageFromServer ??
            'Tindakan ini tidak dibenarkan untuk status semasa. Sila segar semula.',
        type: AppErrorType.conflict,
        statusCode: statusCode,
      );
    case 403:
      return AppException(
        messageFromServer ?? 'Anda tidak mempunyai akses untuk tindakan ini.',
        type: AppErrorType.forbidden,
        statusCode: statusCode,
      );
    case 404:
      return AppException(
        messageFromServer ?? 'Maklumat tidak dijumpai.',
        type: AppErrorType.notFound,
        statusCode: statusCode,
      );
    default:
      if (statusCode >= 500) {
        return AppException(
          messageFromServer ?? 'Server bermasalah, sila cuba lagi.',
          type: AppErrorType.server,
          statusCode: statusCode,
        );
      }
      return AppException(
        messageFromServer ?? fallback,
        type: AppErrorType.unknown,
        statusCode: statusCode,
      );
  }
}

String friendlyErrorMessage(Object error, {String fallback = 'Ralat berlaku. Sila cuba lagi.'}) {
  if (error is String && error.isNotEmpty) {
    return error;
  }
  if (error is AppException) {
    return error.message;
  }
  if (error is DioException) {
    return mapDioError(error, fallback: fallback).message;
  }
  if (error is Exception) {
    return error.toString();
  }
  return fallback;
}

void showErrorSnackBar(BuildContext context, Object error, {String? fallback}) {
  final message = friendlyErrorMessage(error, fallback: fallback ?? 'Ralat berlaku.');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (message is List) {
      final combined = message
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .join('\n');
      if (combined.isNotEmpty) {
        return combined;
      }
    }
  }
  if (data is String && data.isNotEmpty) {
    return data;
  }
  return null;
}
