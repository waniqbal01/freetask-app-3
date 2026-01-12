import 'package:dio/dio.dart';
import '../../models/portfolio_item.dart';
import '../../services/http_client.dart';
import '../../core/utils/api_error_handler.dart';

class PortfolioRepository {
  PortfolioRepository({Dio? dio}) : _dio = dio ?? HttpClient().dio;

  final Dio _dio;

  Future<List<PortfolioItem>> getPortfolio(int userId) async {
    try {
      final response = await _dio.get('/portfolio/$userId');
      final list = (response.data as List).cast<Map<String, dynamic>>();
      return list.map((e) => PortfolioItem.fromJson(e)).toList();
    } on DioException catch (e) {
      await handleApiError(e);
      rethrow;
    }
  }

  Future<PortfolioItem> createPortfolioItem(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/portfolio', data: data);
      return PortfolioItem.fromJson(response.data);
    } on DioException catch (e) {
      await handleApiError(e);
      rethrow;
    }
  }

  Future<PortfolioItem> updatePortfolioItem(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/portfolio/$id', data: data);
      return PortfolioItem.fromJson(response.data);
    } on DioException catch (e) {
      await handleApiError(e);
      rethrow;
    }
  }

  Future<void> deletePortfolioItem(int id) async {
    try {
      await _dio.delete('/portfolio/$id');
    } on DioException catch (e) {
      await handleApiError(e);
      rethrow;
    }
  }
}

final portfolioRepository = PortfolioRepository();
