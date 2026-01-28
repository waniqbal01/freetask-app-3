import 'package:dio/dio.dart';
import '../models/payment.dart';

class PaymentService {
  final Dio _dio;

  PaymentService(this._dio);

  Future<String> createPayment(int jobId, String paymentMethod) async {
    try {
      final response = await _dio.post('/payments/create', data: {
        'jobId': jobId,
        'paymentMethod': paymentMethod, // 'billplz' or 'manual'
        'paymentGateway': 'billplz',
      });

      if (response.data != null && response.data['url'] != null) {
        return response.data['url'];
      }

      throw Exception('Failed to get payment URL');
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  Future<Payment?> getPaymentInfo(int jobId) async {
    try {
      final response = await _dio.get('/payments/job/$jobId');
      if (response.data != null) {
        return Payment.fromJson(response.data);
      }
      return null;
    } catch (e) {
      // Payment might not exist yet, which is okay
      return null;
    }
  }

  Future<String> retryPayment(int jobId) async {
    try {
      final response = await _dio.post('/payments/retry/$jobId');

      if (response.data != null && response.data['url'] != null) {
        return response.data['url'];
      }

      throw Exception('Failed to get retry payment URL');
    } catch (e) {
      throw Exception('Failed to retry payment: $e');
    }
  }

  Future<void> verifyPayment(int jobId, String transactionId) async {
    await _dio.post('/payments/verify', data: {
      'jobId': jobId,
      'transactionId': transactionId,
    });
  }
}
