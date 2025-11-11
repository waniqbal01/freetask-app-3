import 'package:flutter/material.dart';

import '../../../models/service.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.service,
    required this.onView,
    super.key,
  });

  final Service service;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              service.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  label: Text(service.category),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                ),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(service.rating.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'RM${service.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onView,
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
