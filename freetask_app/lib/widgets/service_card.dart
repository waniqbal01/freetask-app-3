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
                const _ServiceThumbnail(),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
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
                          if (service.freelancerName != null &&
                              service.freelancerName!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              service.freelancerName ?? '',
                              style: textTheme.labelMedium
                                  ?.copyWith(color: AppColors.neutral400),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CategoryChip(label: service.category),
                          const SizedBox(width: AppSpacing.s8),
                          const Icon(Icons.person_outline,
                              size: 16, color: AppColors.neutral300),
                          const SizedBox(width: 4),
                          Text(
                            service.freelancerId.isNotEmpty
                                ? 'ID: ${service.freelancerId}'
                                : 'Freelancer',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.neutral400),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          _PriceTag(
                            price: service.price,
                            showWarning: service.isPriceUnavailable,
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: AppColors.neutral300),
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

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 90,
        width: 90,
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
      ),
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
