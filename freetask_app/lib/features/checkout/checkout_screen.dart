import 'package:flutter/material.dart';

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
              const Text('Tiada job draft untuk dipaparkan.')
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checkout belum tersedia dalam versi demo.'),
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
