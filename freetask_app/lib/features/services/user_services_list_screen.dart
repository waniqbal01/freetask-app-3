import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/service.dart';
import 'services_repository.dart';
import '../auth/auth_repository.dart';
import '../../widgets/service_card.dart';

class UserServicesListScreen extends StatefulWidget {
  const UserServicesListScreen({super.key});

  @override
  State<UserServicesListScreen> createState() => _UserServicesListScreenState();
}

class _UserServicesListScreenState extends State<UserServicesListScreen> {
  late Future<List<Service>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  void _loadServices() {
    _servicesFuture = _fetchServices();
  }

  Future<List<Service>> _fetchServices() async {
    final user = await authRepository.getCurrentUser();
    if (user == null) throw Exception('User not logged in');
    return servicesRepository.getServices(freelancerId: int.parse(user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/services/create');
              if (result == true) {
                setState(() {
                  _loadServices();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Service>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Anda belum mempunyai servis.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () async {
                        final result = await context.push('/services/create');
                        if (result == true) {
                          setState(() {
                            _loadServices();
                          });
                        }
                      },
                      child: const Text('Cipta Servis Pertama')),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCard(
                service: service,
                onTap: () => context.push('/service/${service.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
