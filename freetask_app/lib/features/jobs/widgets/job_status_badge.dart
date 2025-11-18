import 'package:flutter/material.dart';

import '../../../models/job.dart';

class JobStatusVisual {
  const JobStatusVisual({
    required this.label,
    required this.badgeText,
    required this.color,
    required this.icon,
  });

  final String label;
  final String badgeText;
  final Color color;
  final IconData icon;

  String get badgeLabel => badgeText.toUpperCase();
}

JobStatusVisual mapJobStatusVisual(JobStatus status) {
  switch (status) {
    case JobStatus.pending:
      return JobStatusVisual(
        label: 'Pending',
        badgeText: 'PENDING',
        color: Colors.amber.shade700,
        icon: Icons.schedule_outlined,
      );
    case JobStatus.inProgress:
      return const JobStatusVisual(
        label: 'In Progress',
        badgeText: 'IN_PROGRESS',
        color: Colors.deepPurple,
        icon: Icons.play_circle_outline,
      );
    case JobStatus.completed:
      return JobStatusVisual(
        label: 'Completed',
        badgeText: 'COMPLETED',
        color: Colors.green.shade700,
        icon: Icons.verified_outlined,
      );
    case JobStatus.rejected:
      return JobStatusVisual(
        label: 'Cancelled',
        badgeText: 'CANCELLED',
        color: Colors.red.shade700,
        icon: Icons.cancel_outlined,
      );
    case JobStatus.disputed:
      return JobStatusVisual(
        label: 'Disputed',
        badgeText: 'CANCELLED',
        color: Colors.red.shade700,
        icon: Icons.gavel_outlined,
      );
  }
}

class JobStatusBadge extends StatelessWidget {
  const JobStatusBadge({super.key, required this.visual});

  final JobStatusVisual visual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visual.icon,
            size: 16,
            color: visual.color,
          ),
          const SizedBox(width: 6),
          Text(
            visual.badgeLabel,
            style: textTheme.labelMedium?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
