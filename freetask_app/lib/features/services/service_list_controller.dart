import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/async_state.dart';
import '../../core/utils/error_utils.dart';
import '../../models/service.dart';
import 'services_repository.dart';

class ServiceListFilters {
  const ServiceListFilters({
    this.searchQuery = '',
    this.category = 'Semua',
    this.priceTier = PriceTier.all,
    this.minRating = 0,
  });

  final String searchQuery;
  final String category;
  final PriceTier priceTier;
  final double minRating;

  ServiceListFilters copyWith({
    String? searchQuery,
    String? category,
    PriceTier? priceTier,
    double? minRating,
  }) {
    return ServiceListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      priceTier: priceTier ?? this.priceTier,
      minRating: minRating ?? this.minRating,
    );
  }
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
  List<Service> _allServices = const <Service>[];

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
      );
      _allServices = services;
      _publishFilteredResults(filters);
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

  void updatePriceTier(PriceTier tier) {
    if (tier == state.filters.priceTier) {
      return;
    }
    final filters = state.filters.copyWith(priceTier: tier);
    state = state.copyWith(
      filters: filters,
      services: _buildFilteredState(filters),
    );
  }

  void updateRating(double rating) {
    if (rating == state.filters.minRating) {
      return;
    }
    final filters = state.filters.copyWith(minRating: rating);
    state = state.copyWith(
      filters: filters,
      services: _buildFilteredState(filters),
    );
  }

  AsyncState<List<Service>> _buildFilteredState(ServiceListFilters filters) {
    final filtered = _applyLocalFilters(_allServices, filters);
    if (filtered.isEmpty) {
      return AsyncState.empty(message: 'Tiada servis menepati penapis ini.');
    }
    return AsyncState.data(filtered);
  }

  void _publishFilteredResults(ServiceListFilters filters) {
    state = state.copyWith(services: _buildFilteredState(filters));
  }

  List<Service> _applyLocalFilters(
    List<Service> services,
    ServiceListFilters filters,
  ) {
    return services.where((service) {
      final matchesPrice = filters.priceTier.matches(service.price);
      final rating = service.averageRating ?? 0;
      final matchesRating = rating >= filters.minRating;
      return matchesPrice && matchesRating;
    }).toList(growable: false);
  }
}

final serviceListControllerProvider =
    StateNotifierProvider.autoDispose<ServiceListController, ServiceListState>((ref) {
  return ServiceListController(repository: servicesRepository);
});

enum PriceTier { all, low, medium, high }

extension PriceTierLabel on PriceTier {
  String get label {
    switch (this) {
      case PriceTier.all:
        return 'Semua harga';
      case PriceTier.low:
        return 'Bawah RM100';
      case PriceTier.medium:
        return 'RM100 - RM500';
      case PriceTier.high:
        return 'RM500 ke atas';
    }
  }

  bool matches(double price) {
    switch (this) {
      case PriceTier.all:
        return true;
      case PriceTier.low:
        return price < 100;
      case PriceTier.medium:
        return price >= 100 && price <= 500;
      case PriceTier.high:
        return price > 500;
    }
  }
}

String _normalizeCategory(String? value) {
  if (value == null || value.isEmpty) {
    return 'Semua';
  }
  return value;
}
