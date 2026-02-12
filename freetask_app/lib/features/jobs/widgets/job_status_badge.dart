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
    case JobStatus.inquiry:
      return const JobStatusVisual(
        label: 'Inquiry',
        badgeText: 'INQUIRY',
        color: Colors.blueAccent,
        icon: Icons.chat_bubble_outline,
      );
    case JobStatus.pending:
      return JobStatusVisual(
        label: 'Pending',
        badgeText: 'PENDING',
        color: Colors.amber.shade700,
        icon: Icons.schedule_outlined,
      );
    case JobStatus.awaitingPayment:
      return JobStatusVisual(
        label: 'Awaiting Payment',
        badgeText: 'AWAITING PAYMENT',
        color: Colors.orange.shade700,
        icon: Icons.payment,
      );
    case JobStatus.accepted:
      return JobStatusVisual(
        label: 'Accepted',
        badgeText: 'ACCEPTED',
        color: Colors.blue.shade700,
        icon: Icons.check_circle_outline,
      );
    case JobStatus.inProgress:
      return const JobStatusVisual(
        label: 'In Progress',
        badgeText: 'IN_PROGRESS',
        color: Colors.deepPurple,
        icon: Icons.play_circle_outline,
      );
    case JobStatus.inReview:
      return const JobStatusVisual(
        label: 'In Review',
        badgeText: 'IN_REVIEW',
        color: Colors.purple,
        icon: Icons.rate_review_outlined,
      );
    case JobStatus.completed:
      return JobStatusVisual(
        label: 'Completed',
        badgeText: 'COMPLETED',
        color: Colors.green.shade700,
        icon: Icons.verified_outlined,
      );
    case JobStatus.cancelled:
      return JobStatusVisual(
        label: 'Cancelled',
        badgeText: 'CANCELLED',
        color: Colors.red.shade700,
        icon: Icons.cancel_outlined,
      );
    case JobStatus.rejected:
      return JobStatusVisual(
        label: 'Rejected',
        badgeText: 'REJECTED',
        color: Colors.red.shade700,
        icon: Icons.block,
      );
    case JobStatus.disputed:
      return JobStatusVisual(
        label: 'Disputed',
        badgeText: 'DISPUTED',
        color: Colors.deepOrange.shade700,
        icon: Icons.gavel_outlined,
      );
    case JobStatus.payoutProcessing:
      return const JobStatusVisual(
        label: 'Processing Payout',
        badgeText: 'PAYOUT...',
        color: Colors.purple,
        icon: Icons.hourglass_top,
      );
    case JobStatus.paidOut:
      return JobStatusVisual(
        label: 'Paid Out',
        badgeText: 'PAID OUT',
        color: Colors.teal.shade700,
        icon: Icons.price_check,
      );
    case JobStatus.payoutFailed:
      return JobStatusVisual(
        label: 'Payout Failed',
        badgeText: 'PAYOUT ERROR',
        color: Colors.red.shade900,
        icon: Icons.error_outline,
      );
    case JobStatus.payoutHold:
      return JobStatusVisual(
        label: 'Payout On Hold',
        badgeText: 'PAYOUT HOLD',
        color: Colors.orange.shade900,
        icon: Icons.warning_amber_rounded,
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
