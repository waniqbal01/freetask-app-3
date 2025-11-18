import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';
import 'widgets/job_status_badge.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job, required this.isClientView});

  final Job job;
  final bool isClientView;

  JobStatusVisual get _statusVisual => mapJobStatusVisual(job.status);

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarikh tidak tersedia';
    }

    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final statusVisual = _statusVisual;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Maklumat Job',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusVisual.color.withOpacity(0.12),
                            ),
                            child: Icon(
                              statusVisual.icon,
                              color: statusVisual.color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.serviceTitle,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                JobStatusBadge(visual: statusVisual),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      const Divider(),
                      const SizedBox(height: AppSpacing.s12),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Tarikh / Masa',
                        value: _formatDate(job.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Service ID',
                        value: job.serviceId,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Jumlah',
                        value: 'RM${job.amount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: isClientView ? 'Freelancer ID' : 'Client ID',
                        value: isClientView ? job.freelancerId : job.clientId,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Job ID',
                        value: job.id,
                      ),
                      if (job.isDisputed) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: AppRadius.mediumRadius,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispute',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                job.disputeReason ?? 'Tiada maklumat tambahan.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
