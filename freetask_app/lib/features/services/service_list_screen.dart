import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/service.dart';
import '../../core/utils/error_utils.dart';
import 'services_repository.dart';
import 'widgets/service_card.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Service>> _servicesFuture;
  List<String> _categories = const <String>['Semua'];
  String _selectedCategory = 'Semua';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _servicesFuture = servicesRepository.getServices();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetchServices);
  }

  void _fetchServices() {
    setState(() {
      _servicesFuture = servicesRepository.getServices(
        query: _searchController.text,
        category: _selectedCategory,
      );
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await servicesRepository.getCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = <String>['Semua', ...categories];
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Semua';
        }
      });
    } catch (_) {
      // Biarkan kategori kekal kepada lalai jika permintaan gagal.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari servis...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _categories
                      .map(
                        (String category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCategory = value;
                    });
                    _fetchServices();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Service>>(
        future: _servicesFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Service>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is DioException) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(resolveDioErrorMessage(error))),
                  );
                }
              });
            }
            return const Center(
              child: Text('Ralat memuatkan servis.'),
            );
          }

          final services = snapshot.data ?? <Service>[];

          if (services.isEmpty) {
            return const Center(
              child: Text('Tiada data'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: services.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final service = services[index];
              return ServiceCard(
                service: service,
                onView: () => context.push('/service/${service.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
