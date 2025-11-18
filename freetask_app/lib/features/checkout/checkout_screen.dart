import 'package:flutter/material.dart';

import '../payments/escrow_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.jobDraft});

  final Map<String, dynamic>? jobDraft;

  @override
  Widget build(BuildContext context) {
    final draft = jobDraft ?? <String, dynamic>{};

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
                    const SizedBox(width: 12),
                    Text(
                      'Checkout',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),
                SectionCard(
                  title: 'Ringkasan Job',
                  child: draft.isEmpty
                      ? const Text('Tiada data')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft['title']?.toString() ?? '- -',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: AppColors.neutral300),
                                const SizedBox(width: 8),
                                Text('Harga: RM${(draft['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.schedule_outlined, color: AppColors.neutral300),
                                const SizedBox(width: 8),
                                Text('Kategori: ${draft['category'] ?? '-'}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (draft['description'] != null) ...[
                              const Text('Deskripsi:'),
                              const SizedBox(height: 8),
                              Text(draft['description'].toString()),
                            ],
                          ],
                        ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final jobId = (draft['jobId'] ?? draft['serviceId'])?.toString();
                      final price = draft['price'];

                      if (jobId == null || jobId.isEmpty || price is! num) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Maklumat job tidak lengkap untuk demo escrow.'),
                          ),
                        );
                        return;
                      }

                      await escrowService.hold(jobId, price.toDouble());

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Dana (demo) RM${price.toStringAsFixed(2)} dipegang untuk status Booked job $jobId.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Teruskan Pembayaran'),
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
