import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/service.dart';
import '../theme/app_theme.dart';
import 'freelancer_avatar.dart';
import '../core/utils/url_utils.dart';

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
              children: [
                // 1. Singleton Freelancer Avatar (Left)
                FreelancerAvatar(
                  avatarUrl: service.freelancerAvatarUrl,
                  size: 50,
                  onTap: () {
                    if (service.freelancerId.isNotEmpty) {
                      GoRouter.of(context)
                          .push('/users/${service.freelancerId}');
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.s12),

                // 2. Info (Middle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _CategoryChip(label: service.category),
                          if (service.isPending) const _PendingChip(),
                          if (service.isRejected) const _RejectedChip(),
                        ],
                      ),
                      if (service.isRejected &&
                          service.rejectionReason != null &&
                          service.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _RejectionBanner(reason: service.rejectionReason!),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.neutral400),
                      ),
                      const SizedBox(height: 12),
                      _PriceTag(
                        price: service.price,
                        showWarning: service.isPriceUnavailable,
                      ),
                    ],
                  ),
                ),

                // 3. Thumbnail (Right) - Small/Medium
                if (service.thumbnailUrl != null &&
                    service.thumbnailUrl!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.s12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.network(
                        UrlUtils.resolveImageUrl(service.thumbnailUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
            // Avatar Left
            ClipOval(
              child: Container(
                height: 50,
                width: 50,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 12),
            // Info Middle
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
                  _SkeletonLine(widthFactor: 0.3, height: 16),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Image Right
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 80,
                width: 80,
                color: theme.colorScheme.surfaceContainerHighest,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final safeWidth =
            maxWidth.isFinite ? maxWidth : MediaQuery.of(context).size.width;

        return SizedBox(
          width: safeWidth,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }
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
  const _PriceTag({required this.price, required this.showWarning});

  final double price;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    if (showWarning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Harga belum tersedia / invalid, sila refresh',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }

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

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded,
              size: 12, color: Colors.orange.shade800),
          const SizedBox(width: 4),
          Text(
            'PENDING',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _RejectedChip extends StatelessWidget {
  const _RejectedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, size: 12, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Text(
            'DITOLAK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Sebab penolakan: $reason',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
