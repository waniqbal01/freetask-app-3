import 'package:flutter/material.dart';

import '../payments/escrow_service.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.jobDraft});

  final Map<String, dynamic>? jobDraft;

  @override
  Widget build(BuildContext context) {
    final draft = jobDraft ?? <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Job',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (draft.isEmpty)
              const Text('Tiada data')
            else ...[
              Text('Servis: ${draft['title'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Harga: RM${(draft['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
              const SizedBox(height: 8),
              Text('Tempoh siap: ${draft['deliveryDays'] ?? '-'} hari'),
              const SizedBox(height: 16),
              const Text('Termasuk:'),
              const SizedBox(height: 8),
              ...(draft['includes'] as List<dynamic>? ?? <dynamic>[])
                  .map((dynamic item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(item.toString())),
                          ],
                        ),
                      )),
            ],
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
    );
  }
}
