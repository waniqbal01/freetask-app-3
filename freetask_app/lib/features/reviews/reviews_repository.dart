import 'dart:async';

import '../jobs/jobs_repository.dart';

class Review {
  Review({
    required this.jobId,
    required this.serviceId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String jobId;
  final String serviceId;
  final int rating;
  final String comment;
  final DateTime createdAt;
}

class ReviewsRepository {
  ReviewsRepository();

  final Map<String, List<Review>> _reviewsByServiceId =
      <String, List<Review>>{};
  final Set<String> _submittedJobIds = <String>{};

  Future<bool> submit(String jobId, int rating, String comment) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final job = jobsRepository.getJobById(jobId);
    if (job == null) {
      return false;
    }

    final normalizedRating = rating.clamp(1, 5);
    final sanitizedComment = comment.trim();

    final review = Review(
      jobId: jobId,
      serviceId: job.serviceId,
      rating: normalizedRating,
      comment: sanitizedComment,
      createdAt: DateTime.now(),
    );

    final reviews =
        _reviewsByServiceId.putIfAbsent(job.serviceId, () => <Review>[]);
    reviews.removeWhere((Review existing) => existing.jobId == jobId);
    reviews.add(review);
    _submittedJobIds.add(jobId);
    return true;
  }

  List<Review> getReviewsForService(String serviceId) {
    final reviews = _reviewsByServiceId[serviceId];
    if (reviews == null) {
      return const <Review>[];
    }
    final sorted = List<Review>.from(reviews)
      ..sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));
    return List<Review>.unmodifiable(sorted);
  }

  bool hasSubmittedReview(String jobId) => _submittedJobIds.contains(jobId);
}

final reviewsRepository = ReviewsRepository();
