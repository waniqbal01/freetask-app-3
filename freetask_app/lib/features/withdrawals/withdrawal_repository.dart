import 'package:dio/dio.dart';
import '../../core/utils/api_response.dart';
import '../../models/withdrawal.dart';

class WithdrawalRepository {
  final Dio _dio;

  WithdrawalRepository({required Dio dio}) : _dio = dio;

  Future<ApiResponse<Withdrawal>> createWithdrawal({
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    try {
      final response = await _dio.post(
        '/withdrawals',
        data: {
          'amount': amount,
          'bankDetails': bankDetails,
        },
      );

      return ApiResponse.success(Withdrawal.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to create withdrawal');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<List<Withdrawal>>> getMyWithdrawals() async {
    try {
      final response = await _dio.get('/withdrawals/me');
      final List<dynamic> data = response.data;
      final withdrawals =
          data.map((json) => Withdrawal.fromJson(json)).toList();

      return ApiResponse.success(withdrawals);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch withdrawals');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getBalance() async {
    try {
      final response = await _dio.get('/withdrawals/balance');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch balance');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }
}
