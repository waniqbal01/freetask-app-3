import 'package:dio/dio.dart';
import '../../core/utils/api_response.dart';

class AdminRepository {
  final Dio _dio;

  AdminRepository({required Dio dio}) : _dio = dio;

  // Analytics
  Future<ApiResponse<Map<String, dynamic>>> getAnalytics() async {
    try {
      final response = await _dio.get('/admin/analytics');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch analytics');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getSystemStats() async {
    try {
      final response = await _dio.get('/admin/stats');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch stats');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // User Management
  Future<ApiResponse<Map<String, dynamic>>> getUsers(
      {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/admin/users',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch users');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> updateUserStatus({
    required int userId,
    required bool isActive,
  }) async {
    try {
      final response = await _dio.patch(
        '/admin/users/$userId/status',
        data: {'status': isActive ? 'ACTIVE' : 'BANNED'},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to update user status');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateTrustScore({
    required int userId,
    required int score,
  }) async {
    try {
      final response = await _dio.patch(
        '/admin/users/$userId/trust-score',
        data: {'trustScore': score},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to update trust score');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Service Approval
  Future<ApiResponse<Map<String, dynamic>>> getPendingServices(
      {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/admin/services/pending',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch pending services');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> approveService(int serviceId) async {
    try {
      final response = await _dio.patch('/admin/services/$serviceId/approve');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to approve service');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> rejectService({
    required int serviceId,
    required String reason,
  }) async {
    try {
      final response = await _dio.patch(
        '/admin/services/$serviceId/reject',
        data: {'reason': reason},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to reject service');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Order Monitoring
  Future<ApiResponse<Map<String, dynamic>>> getAllOrders({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/orders',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (status != null) 'status': status,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch orders');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> getOrderDetails(int orderId) async {
    try {
      final response = await _dio.get('/admin/orders/$orderId');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch order details');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Withdrawal Management
  Future<ApiResponse<Map<String, dynamic>>> getWithdrawals({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/withdrawals',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (status != null) 'status': status,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch withdrawals');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> approveWithdrawal(int withdrawalId) async {
    try {
      final response =
          await _dio.patch('/admin/withdrawals/$withdrawalId/approve');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to approve withdrawal');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> rejectWithdrawal({
    required int withdrawalId,
    String? reason,
  }) async {
    try {
      final response = await _dio.patch(
        '/admin/withdrawals/$withdrawalId/reject',
        data: {'reason': reason},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to reject withdrawal');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Dispute Management
  Future<ApiResponse<Map<String, dynamic>>> getDisputes(
      {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/admin/disputes',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to fetch disputes');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> resolveDispute({
    required int jobId,
    required String resolution,
    double? refundAmount,
    String? notes,
  }) async {
    try {
      final response = await _dio.patch(
        '/admin/disputes/$jobId/resolve',
        data: {
          'resolution': resolution,
          if (refundAmount != null) 'refundAmount': refundAmount,
          if (notes != null) 'notes': notes,
        },
      );
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to resolve dispute');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  // Bank Verification
  Future<ApiResponse<List<dynamic>>> getPendingBankVerifications() async {
    try {
      final response = await _dio.get('/users/pending-bank-verification');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(e.response?.data['message'] ??
          'Failed to fetch pending verifications');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }

  Future<ApiResponse<dynamic>> verifyBankDetails(int userId) async {
    try {
      final response = await _dio.patch('/users/$userId/verify-bank');
      return ApiResponse.success(response.data);
    } on DioException catch (e) {
      return ApiResponse.error(
          e.response?.data['message'] ?? 'Failed to verify bank details');
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred');
    }
  }
}
