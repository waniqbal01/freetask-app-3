import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../payments/escrow_service.dart';
import 'jobs_repository.dart';
import '../../core/utils/error_utils.dart';

class JobCheckoutScreen extends StatefulWidget {
  const JobCheckoutScreen({super.key, this.serviceSummary});

  final Map<String, dynamic>? serviceSummary;

  @override
  State<JobCheckoutScreen> createState() => _JobCheckoutScreenState();
}

class _JobCheckoutScreenState extends State<JobCheckoutScreen> {
  bool _isSubmitting = false;

  Map<String, dynamic> get _summary =>
      widget.serviceSummary ?? <String, dynamic>{};

  String get _serviceId => (_summary['serviceId'] ?? '') as String;

  String get _description => _summary['description']?.toString() ?? '';

  double? get _amount {
    final value = _summary['price'];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  Future<void> _createOrder() async {
    final serviceId = _serviceId;
    final amount = _amount;
    final description = _description;

    if (serviceId.isEmpty || amount == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maklumat servis tidak lengkap.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final job =
          await jobsRepository.createOrder(serviceId, amount, description);
      await escrowService.hold(job.id, job.amount);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${job.id} dicipta. Dana (demo) RM${job.amount.toStringAsFixed(2)} dipegang untuk status Booked.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolveDioErrorMessage(error))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat mencipta order: $error')),
      );
    } finally {
      if (!mounted) {
        // ignore: control_flow_in_finally
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _summary['title']?.toString();
    final includes = (_summary['includes'] as List<dynamic>?)?.cast<String>();
    final delivery = _summary['deliveryDays'];

    return Scaffold(
      appBar: AppBar(title: const Text('Job Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Servis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              Text('Servis ID: $_serviceId'),
            const SizedBox(height: 12),
            if (delivery != null) Text('Tempoh siap: $delivery hari'),
            const SizedBox(height: 12),
            Text('Jumlah: RM${(_amount ?? 0).toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            if (includes != null && includes.isNotEmpty) ...[
              Text(
                'Termasuk:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...includes.map(
                (String item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _createOrder,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Order (Escrow Hold)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
