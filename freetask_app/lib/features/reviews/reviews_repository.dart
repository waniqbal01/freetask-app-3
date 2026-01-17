import 'package:dio/dio.dart';

import '../../features/auth/auth_repository.dart';
import '../../services/http_client.dart';
import '../../core/storage/storage.dart';
import '../../core/utils/api_error_handler.dart';

class Review {
  Review({
    required this.id,
    required this.jobId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reviewerId,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      jobId: json['jobId'] is int
          ? json['jobId'] as int
          : int.tryParse('${json['job_id'] ?? json['jobId']}') ?? 0,
      rating: json['rating'] is int
          ? json['rating'] as int
          : int.tryParse('${json['rating']}') ?? 0,
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ??
              json['createdAt']?.toString() ??
              '') ??
          DateTime.now(),
      reviewerId: json['reviewerId'] is int
          ? json['reviewerId'] as int
          : int.tryParse('${json['reviewer_id'] ?? json['reviewerId']}'),
    );
  }

  final int id;
  final int jobId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final int? reviewerId;
}

class ReviewsRepository {
  ReviewsRepository({Dio? dio, AppStorage? storage})
      : _dio = dio ?? HttpClient().dio,
        _storage = storage ?? appStorage;

  final Dio _dio;
  final AppStorage _storage;
  final Set<int> _submittedJobIds = <int>{};

  bool hasSubmittedReview(String jobId) {
    final parsed = int.tryParse(jobId);
    if (parsed == null) {
      return false;
    }
    return _submittedJobIds.contains(parsed);
  }

  Future<Review> createReview({
    required int jobId,
    required int revieweeId,
    required int rating,
    String? comment,
  }) async {
    final token = await _requireAuthToken();
    final sanitizedComment =
        (comment?.trim().isEmpty ?? true) ? null : comment!.trim();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reviews',
        data: <String, dynamic>{
          'jobId': jobId,
          'revieweeId': revieweeId,
          'rating': rating,
          if (sanitizedComment != null) 'comment': sanitizedComment,
        },
        options: Options(
            headers: <String, String>{'Authorization': 'Bearer $token'}),
      );
      final review = Review.fromJson(response.data ?? <String, dynamic>{});
      _submittedJobIds.add(review.jobId);
      return review;
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  Future<List<Review>> getReviewsForJob(int jobId) async {
    final token = await _requireAuthToken();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reviews',
        queryParameters: <String, dynamic>{'jobId': jobId},
        options: Options(
            headers: <String, String>{'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? <dynamic>[];
      final reviews = data
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(growable: false);
      _syncSubmittedJobs(reviews);
      return reviews;
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  Future<List<Review>> getMyReviews() async {
    final token = await _requireAuthToken();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reviews/mine',
        options: Options(
            headers: <String, String>{'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? <dynamic>[];
      final reviews = data
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(growable: false);
      _syncSubmittedJobs(reviews);
      return reviews;
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  Future<List<Review>> getSubmittedReviews() async {
    final token = await _requireAuthToken();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reviews/submitted',
        options: Options(
            headers: <String, String>{'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? <dynamic>[];
      final reviews = data
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(growable: false);
      _syncSubmittedJobs(reviews);
      return reviews;
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  Future<List<Review>> getReviewsForFreelancer(int freelancerId) async {
    final token = await _requireAuthToken();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reviews',
        queryParameters: <String, dynamic>{'freelancerId': freelancerId},
        options: Options(
            headers: <String, String>{'Authorization': 'Bearer $token'}),
      );
      final data = response.data ?? <dynamic>[];
      final reviews = data
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(growable: false);
      _syncSubmittedJobs(reviews);
      return reviews;
    } on DioException catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  void _syncSubmittedJobs(Iterable<Review> reviews) {
    for (final review in reviews) {
      _submittedJobIds.add(review.jobId);
    }
  }

  Future<String> _requireAuthToken() async {
    final token = await _storage.read(AuthRepository.tokenStorageKey);
    if (token == null || token.isEmpty) {
      throw const AuthRequiredException(
          'Sila log masuk untuk buat/lihat review');
    }
    return token;
  }
}

final reviewsRepository = ReviewsRepository();

class AuthRequiredException implements Exception {
  const AuthRequiredException(this.message);
  final String message;

  @override
  String toString() => message;
}
