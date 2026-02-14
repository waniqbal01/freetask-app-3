import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/service.dart';
import 'services_repository.dart';
import '../../widgets/service_card.dart';

class UserServicesView extends StatefulWidget {
  const UserServicesView({super.key});

  @override
  State<UserServicesView> createState() => _UserServicesViewState();
}

class _UserServicesViewState extends State<UserServicesView> {
  late Future<List<Service>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _loadServices() {
    setState(() {
      _servicesFuture = _fetchServices();
    });
  }

  Future<List<Service>> _fetchServices() async {
    // We use getMyServices to fetch all services (including pending) for the current user
    return servicesRepository.getMyServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Service>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadServices,
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          );
        }

        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.design_services_outlined,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Anda belum mempunyai servis.'),
                const SizedBox(height: 16),
                // Button is handled by parent screen now, but we can keep a call to action here if needed
                // or just leave it empty.
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadServices();
            await _servicesFuture;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCard(
                service: service,
                onTap: () async {
                  // Navigate directly to edit screen for owned services
                  final result = await context.push(
                    '/services/${service.id}/edit',
                    extra: service,
                  );
                  // Refresh on return if edited or deleted
                  if (result == true) {
                    _loadServices();
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
