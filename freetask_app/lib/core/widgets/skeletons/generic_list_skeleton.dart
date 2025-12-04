import 'package:flutter/material.dart';

/// Generic skeleton loader for list views.
/// Can be used as a placeholder while loading any type of list content.
class GenericListSkeleton extends StatelessWidget {
  const GenericListSkeleton({
    this.itemCount = 5,
    this.itemHeight = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => GenericSkeletonItem(height: itemHeight),
    );
  }
}

/// Single skeleton item for generic lists
class GenericSkeletonItem extends StatelessWidget {
  const GenericSkeletonItem({
    this.height = 100,
    super.key,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonCircle(diameter: height * 0.4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(
                      widthFactor: 0.7,
                      height: height * 0.15,
                    ),
                    SizedBox(height: height * 0.08),
                    _SkeletonLine(
                      widthFactor: 0.5,
                      height: height * 0.12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: height * 0.12),
          _SkeletonLine(
            widthFactor: 1,
            height: height * 0.1,
          ),
        ],
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

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: diameter,
      width: diameter,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}
