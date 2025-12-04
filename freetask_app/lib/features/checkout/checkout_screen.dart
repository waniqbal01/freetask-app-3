import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../escrow/escrow_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_card.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.jobDraft});

  final Map<String, dynamic>? jobDraft;

  @override
  Widget build(BuildContext context) {
    final draft = jobDraft ?? <String, dynamic>{};
    final rawPrice = draft['price'];
    double? parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String && rawPrice.isNotEmpty) {
      parsedPrice = double.tryParse(rawPrice);
    }
    final priceText = parsedPrice == null || parsedPrice <= 0
        ? 'Harga belum tersedia / invalid'
        : 'RM${parsedPrice.toStringAsFixed(2)}';

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
                                const Icon(Icons.payments_outlined,
                                    color: AppColors.neutral300),
                                const SizedBox(width: 8),
                                Text('Harga: $priceText'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'Maklumat tambahan tidak tersedia untuk demo ini.'),
                          ],
                        ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final jobId =
                          (draft['jobId'] ?? draft['serviceId'])?.toString();
                      final price = parsedPrice;

                      if (jobId == null ||
                          jobId.isEmpty ||
                          price == null ||
                          price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Maklumat job tidak lengkap untuk demo escrow.'),
                          ),
                        );
                        return;
                      }

                      try {
                        await escrowRepository.hold(jobId);

                        if (!context.mounted) return;

                        // UX-C-05: Redirect to job detail with success flag
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Dana RM${price.toStringAsFixed(2)} dipegang untuk job $jobId.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        // Navigate to job detail with fromCheckout flag
                        context.go('/jobs/$jobId', extra: {
                          'fromCheckout': true,
                        });
                      } on EscrowUnavailable catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      } on DioException catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.response?.data.toString() ??
                                  'Ralat escrow.',
                            ),
                          ),
                        );
                      }
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
