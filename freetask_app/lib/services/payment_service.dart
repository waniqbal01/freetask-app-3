import 'package:dio/dio.dart';

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

  Future<void> verifyPayment(int jobId, String transactionId) async {
    await _dio.post('/payments/verify', data: {
      'jobId': jobId,
      'transactionId': transactionId,
    });
  }
}
