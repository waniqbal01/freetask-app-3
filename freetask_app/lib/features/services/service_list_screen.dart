import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../models/service.dart';
import '../../widgets/service_card.dart';
import 'services_repository.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Service> _services = <Service>[];
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _categories = const <String>['Semua'];
  String _selectedCategory = 'Semua';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchServices();
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

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await servicesRepository.getServices(
        q: _searchController.text,
        category: _selectedCategory,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _services
          ..clear()
          ..addAll(services);
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final message = resolveDioErrorMessage(error);
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      const message = 'Tidak dapat memuatkan servis. Sila cuba lagi.';
      setState(() {
        _errorMessage = message;
      });
      showErrorSnackBar(context, '$message\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Gagal memuat kategori: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CustomScrollView(
                  slivers: <Widget>[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari servis...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemBuilder:
                                    (BuildContext context, int index) {
                                  final category = _categories[index];
                                  final isSelected =
                                      category == _selectedCategory;
                                  return ChoiceChip(
                                    label: Text(category),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                      _fetchServices();
                                    },
                                    selectedColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  );
                                },
                                separatorBuilder: (BuildContext context, int _) =>
                                    const SizedBox(width: 8),
                                itemCount: _categories.length,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              if (index.isOdd) {
                                return const SizedBox(height: 12);
                              }
                              return const ServiceCardSkeleton();
                            },
                            childCount: (6 * 2) - 1,
                          ),
                        ),
                      )
                    else if (_errorMessage != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _fetchServices,
                                child: const Text('Cuba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_services.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Tiada data')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              if (index.isOdd) {
                                return const SizedBox(height: 12);
                              }
                              final service = _services[index ~/ 2];
                              return ServiceCard(
                                service: service,
                                onTap: () =>
                                    context.push('/service/${service.id}'),
                              );
                            },
                            childCount: (_services.length * 2) - 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
