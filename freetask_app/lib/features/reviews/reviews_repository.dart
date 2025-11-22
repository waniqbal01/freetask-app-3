import 'package:dio/dio.dart';

import '../../services/http_client.dart';

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
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      jobId: json['jobId'] is int
          ? json['jobId'] as int
          : int.tryParse('${json['job_id'] ?? json['jobId']}') ?? 0,
      rating: json['rating'] is int
          ? json['rating'] as int
          : int.tryParse('${json['rating']}') ?? 0,
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ??
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
  ReviewsRepository({Dio? dio}) : _dio = dio ?? HttpClient().dio;

  final Dio _dio;
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
    required int rating,
    String? comment,
  }) async {
    final sanitizedComment = (comment?.trim().isEmpty ?? true) ? null : comment!.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/reviews',
      data: <String, dynamic>{
        'jobId': jobId,
        'rating': rating,
        if (sanitizedComment != null) 'comment': sanitizedComment,
      },
    );
    final review = Review.fromJson(response.data ?? <String, dynamic>{});
    _submittedJobIds.add(review.jobId);
    return review;
  }

  Future<List<Review>> getReviewsForJob(int jobId) async {
    final response = await _dio.get<List<dynamic>>(
      '/reviews',
      queryParameters: <String, dynamic>{'jobId': jobId},
    );
    final data = response.data ?? <dynamic>[];
    final reviews = data
        .whereType<Map<String, dynamic>>()
        .map(Review.fromJson)
        .toList(growable: false);
    _syncSubmittedJobs(reviews);
    return reviews;
  }

  Future<List<Review>> getMyReviews() async {
    final response = await _dio.get<List<dynamic>>('/reviews/mine');
    final data = response.data ?? <dynamic>[];
    final reviews = data
        .whereType<Map<String, dynamic>>()
        .map(Review.fromJson)
        .toList(growable: false);
    _syncSubmittedJobs(reviews);
    return reviews;
  }

  void _syncSubmittedJobs(Iterable<Review> reviews) {
    for (final review in reviews) {
      _submittedJobIds.add(review.jobId);
    }
  }
}

final reviewsRepository = ReviewsRepository();
