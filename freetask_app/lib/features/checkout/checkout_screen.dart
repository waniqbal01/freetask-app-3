import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/payment_service.dart';
import '../../services/http_client.dart';
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
                                Text(
                                  priceText,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green),
                                ),
                              ],
                            ),
                            if (draft['description'] != null &&
                                draft['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Penerangan Kerja:',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                draft['description'].toString(),
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ],
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
                        final jobIdInt = int.tryParse(jobId);
                        if (jobIdInt == null) {
                          throw Exception('ID Job tidak sah: $jobId');
                        }

                        // UX-C-05: Create real payment via Billplz
                        final paymentService = PaymentService(HttpClient().dio);
                        final paymentUrl = await paymentService.createPayment(
                            jobIdInt, 'billplz');

                        if (!context.mounted) return;

                        // Navigate to Billplz checkout
                        final uri = Uri.parse(paymentUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Diarahkan ke halaman pembayaran Billplz...'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          // Navigate to jobs tab instead of staying on checkout
                          context.go('/jobs');
                        } else {
                          throw Exception(
                              'Tidak dapat membuka pautan pembayaran.');
                        }
                      } on DioException catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.response?.data.toString() ??
                                  'Ralat membuka laman bayaran.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ralat: $error'),
                            backgroundColor: Colors.red,
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
