import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/async_state.dart';
import '../../core/utils/error_utils.dart';
import '../../models/service.dart';
import 'services_repository.dart';

class ServiceListFilters {
  const ServiceListFilters({
    this.searchQuery = '',
    this.category = 'Semua',
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.maxDeliveryDays,
  });

  final String searchQuery;
  final String category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final int? maxDeliveryDays;

  ServiceListFilters copyWith({
    String? searchQuery,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxDeliveryDays,
  }) {
    return ServiceListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      maxDeliveryDays: maxDeliveryDays ?? this.maxDeliveryDays,
    );
  }

  bool get hasActiveFilters =>
      (minPrice != null || maxPrice != null || minRating != null || maxDeliveryDays != null) &&
      (minPrice != 0 || maxPrice != 0 || minRating != 0 || maxDeliveryDays != 0);
}

class ServiceListState {
  const ServiceListState({
    this.filters = const ServiceListFilters(),
    this.services = const AsyncState<List<Service>>.initial(),
    this.categories = const <String>['Semua'],
  });

  final ServiceListFilters filters;
  final AsyncState<List<Service>> services;
  final List<String> categories;

  ServiceListState copyWith({
    ServiceListFilters? filters,
    AsyncState<List<Service>>? services,
    List<String>? categories,
  }) {
    return ServiceListState(
      filters: filters ?? this.filters,
      services: services ?? this.services,
      categories: categories ?? this.categories,
    );
  }
}

class ServiceListController extends StateNotifier<ServiceListState> {
  ServiceListController({required this.repository}) : super(const ServiceListState());

  final ServicesRepository repository;
  bool _bootstrapped = false;

  Future<void> bootstrap({String? initialCategory, String? initialQuery}) async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    var filters = state.filters;
    if (initialCategory != null && initialCategory.isNotEmpty) {
      filters = filters.copyWith(category: _normalizeCategory(initialCategory));
    }
    if (initialQuery != null && initialQuery.isNotEmpty) {
      filters = filters.copyWith(searchQuery: initialQuery);
    }
    state = state.copyWith(filters: filters);

    await Future.wait([
      loadCategories(),
      refresh(),
    ]);
  }

  Future<void> refresh() async {
    final filters = state.filters;
    state = state.copyWith(services: AsyncState.loading(message: 'Memuat senarai servis...'));
    try {
      final services = await repository.getServices(
        q: filters.searchQuery,
        category: filters.category,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        minRating: filters.minRating,
        maxDeliveryDays: filters.maxDeliveryDays,
      );
      if (services.isEmpty) {
        state = state.copyWith(
          services: AsyncState.empty(message: 'Tiada servis menepati penapis ini.'),
        );
      } else {
        state = state.copyWith(services: AsyncState.data(services));
      }
    } on AppException catch (error) {
      state = state.copyWith(
        services: AsyncState.error(error: error, message: error.message),
      );
    } catch (error) {
      state = state.copyWith(
        services: AsyncState.error(
          error: error,
          message: 'Tidak dapat memuatkan servis. Sila cuba lagi.',
        ),
      );
    }
  }

  Future<void> loadCategories() async {
    try {
      final categories = await repository.getCategories();
      state = state.copyWith(categories: <String>{'Semua', ...categories}.toList());
    } catch (_) {
      // Categories are not critical for rendering; keep existing list and surface
      // errors via snackbar on the screen.
    }
  }

  Future<void> updateSearchQuery(String query) {
    final filters = state.filters.copyWith(searchQuery: query.trim());
    state = state.copyWith(filters: filters);
    return refresh();
  }

  Future<void> selectCategory(String category) {
    final normalized = _normalizeCategory(category);
    if (normalized == state.filters.category) {
      return Future.value();
    }
    final filters = state.filters.copyWith(category: normalized);
    state = state.copyWith(filters: filters);
    return refresh();
  }

  Future<void> applyFilters(ServiceListFilters filters) {
    state = state.copyWith(filters: filters);
    return refresh();
  }
}

final serviceListControllerProvider =
    StateNotifierProvider.autoDispose<ServiceListController, ServiceListState>((ref) {
  return ServiceListController(repository: servicesRepository);
});

String _normalizeCategory(String? value) {
  if (value == null || value.isEmpty) {
    return 'Semua';
  }
  return value;
}
