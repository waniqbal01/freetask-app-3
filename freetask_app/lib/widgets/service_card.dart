import 'package:flutter/material.dart';

import '../models/service.dart';

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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  color: theme.colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.category,
                      style: textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Text(
                          'RM${service.price.toStringAsFixed(2)}',
                          style: textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.rating.toStringAsFixed(1),
                          style: textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
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
                color: theme.colorScheme.surfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
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
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
