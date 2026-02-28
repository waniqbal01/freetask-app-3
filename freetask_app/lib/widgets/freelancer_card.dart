import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'freelancer_avatar.dart';

class FreelancerCard extends StatelessWidget {
  const FreelancerCard({
    required this.user,
    required this.onTap,
    this.onAvatarTap,
    super.key,
  });

  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FreelancerAvatar(
                      avatarUrl: user.avatarUrl,
                      size: 64,
                      onTap: onAvatarTap ?? onTap,
                    ),
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neutral900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              if (user.rate != null)
                                Text(
                                  'RM${user.rate!.toStringAsFixed(0)}',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: AppColors.neutral400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${user.district}, ${user.state}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.neutral500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (user.rate != null)
                                Text(
                                  '/jam',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.neutral400,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _LevelChip(level: user.level),
                              const SizedBox(width: 8),
                              _RatingChip(
                                rating: user.rating ?? 0.0,
                                count: user.reviewCount ?? 0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user.skills != null && user.skills!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.skills!
                        .take(3)
                        .map((skill) => _SkillChip(label: skill))
                        .toList()
                      ..addAll(
                        user.skills!.length > 3
                            ? [_SkillChip(label: '+${user.skills!.length - 3}')]
                            : [],
                      ),
                  ),
                ],
                if (user.serviceNames != null &&
                    user.serviceNames!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: user.serviceNames!
                          .take(5)
                          .map((serviceName) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _ServiceChip(label: serviceName),
                              ))
                          .toList(),
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

class FreelancerCardSkeleton extends StatelessWidget {
  const FreelancerCardSkeleton({super.key});

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
            ClipOval(
              child: Container(
                height: 60,
                width: 60,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SkeletonLine(widthFactor: 0.5, height: 18),
                      const _SkeletonLine(widthFactor: 0.2, height: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _SkeletonLine(widthFactor: 0.4, height: 14),
                  const SizedBox(height: 10),
                  const _SkeletonLine(widthFactor: 1, height: 12),
                  const SizedBox(height: 6),
                  const _SkeletonLine(widthFactor: 0.85, height: 12),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      _SkeletonLine(widthFactor: 0.2, height: 24),
                      SizedBox(width: 8),
                      _SkeletonLine(widthFactor: 0.2, height: 24),
                    ],
                  )
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

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (level) {
      case 'PRO':
        color = Colors.purple;
        label = 'Pro';
        icon = Icons.star;
        break;
      case 'STANDARD':
        color = Colors.blue;
        label = 'Standard';
        icon = Icons.verified;
        break;
      default:
        color = Colors.green;
        label = 'Newbie';
        icon = Icons.circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 2),
        Text(
          count > 0 ? rating.toStringAsFixed(1) : 'Tiada Rating',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.neutral900,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.neutral400,
                ),
          ),
        ],
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.neutral600,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 12, color: AppColors.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
