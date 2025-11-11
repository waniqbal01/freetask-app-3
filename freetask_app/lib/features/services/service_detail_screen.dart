import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import 'services_repository.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Future<Service?> _serviceFuture;

  @override
  void initState() {
    super.initState();
    _serviceFuture = servicesRepository.getServiceById(widget.serviceId);
  }

  void _handleHire(Service service) {
    final jobDraft = <String, dynamic>{
      'serviceId': service.id,
      'title': service.title,
      'price': service.price,
      'deliveryDays': service.deliveryDays,
      'includes': service.includes,
    };

    context.push('/jobs/checkout', extra: jobDraft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maklumat Servis')),
      body: FutureBuilder<Service?>(
        future: _serviceFuture,
        builder: (BuildContext context, AsyncSnapshot<Service?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Servis tidak ditemui.'),
            );
          }

          final service = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(service.rating.toStringAsFixed(1)),
                    const SizedBox(width: 16),
                    Chip(
                      label: Text(service.category),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  service.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Text(
                  'Harga: RM${service.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text('Tempoh siap: ${service.deliveryDays} hari'),
                const SizedBox(height: 24),
                Text(
                  'Termasuk:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...service.includes.map(
                  (String include) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(include)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleHire(service),
                    child: const Text('Hire'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
