import 'package:flutter/material.dart';

import '../models/service.dart';
import '../theme/app_theme.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.service,
    required this.onTap,
    super.key,
  });

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ServiceThumbnail(imageUrl: service.thumbnailUrl),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          _PriceTag(price: service.price),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FreelancerAvatar(imageUrl: service.freelancerAvatarUrl),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              service.freelancerName?.isNotEmpty == true
                                  ? service.freelancerName!
                                  : 'Freelancer #${service.freelancerId}',
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rate_rounded,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            _buildRatingLabel(service),
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.neutral500),
                          ),
                          const Spacer(),
                          const Icon(Icons.work_outline,
                              size: 18, color: AppColors.neutral400),
                          const SizedBox(width: 6),
                          Text(
                            service.completedJobs != null
                                ? '${service.completedJobs} job selesai'
                                : 'Job pertama menanti',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.neutral500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.neutral500),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _CategoryChip(label: service.category),
                          const Spacer(),
                          Text(
                            'Lihat servis',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppRadius.largeRadius,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 86,
                width: 86,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SkeletonLine(widthFactor: 0.75, height: 18),
                  SizedBox(height: 8),
                  _SkeletonLine(widthFactor: 0.4, height: 14),
                  SizedBox(height: 10),
                  _SkeletonLine(widthFactor: 1, height: 12),
                  SizedBox(height: 6),
                  _SkeletonLine(widthFactor: 0.85, height: 12),
                  SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _SkeletonLine(widthFactor: 0.3, height: 16),
                      Spacer(),
                      _SkeletonLine(widthFactor: 0.18, height: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 90,
        width: 90,
        color: AppColors.neutral50,
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ThumbnailPlaceholder(),
              )
            : const _ThumbnailPlaceholder(),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.design_services_rounded,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
}

class _FreelancerAvatar extends StatelessWidget {
  const _FreelancerAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.neutral100,
        child: const Icon(Icons.person_outline, size: 18, color: AppColors.neutral500),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(imageUrl!),
      backgroundColor: AppColors.neutral100,
    );
  }
}

String _buildRatingLabel(Service service) {
  final rating = service.averageRating;
  final reviews = service.reviewCount ?? 0;
  if (rating == null || rating == 0) {
    return 'Belum ada rating';
  }
  final formattedRating = rating.toStringAsFixed(1);
  if (reviews <= 0) {
    return formattedRating;
  }
  return '$formattedRating · ${reviews} ulasan';
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        'RM${price.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
