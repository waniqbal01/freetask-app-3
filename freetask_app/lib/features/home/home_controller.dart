import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/async_state.dart';
import '../../core/utils/error_utils.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../auth/auth_repository.dart';
import '../services/services_repository.dart';

class HomeState {
  const HomeState({
    this.user,
    this.categories = const <String>[],
    this.featured = const AsyncState<List<Service>>.initial(),
  });

  final AppUser? user;
  final List<String> categories;
  final AsyncState<List<Service>> featured;

  static const _sentinel = Object();

  HomeState copyWith({
    Object? user = _sentinel,
    List<String>? categories,
    AsyncState<List<Service>>? featured,
  }) {
    return HomeState(
      user: identical(user, _sentinel) ? this.user : user as AppUser?,
      categories: categories ?? this.categories,
      featured: featured ?? this.featured,
    );
  }
}

class HomeController extends StateNotifier<HomeState> {
  HomeController({
    required this.authRepository,
    required this.servicesRepository,
  }) : super(const HomeState()) {
    refresh();
  }

  final AuthRepository authRepository;
  final ServicesRepository servicesRepository;

  Future<void> refresh() async {
    state = state.copyWith(featured: AsyncState.loading());
    try {
      final results = await Future.wait([
        authRepository.getCurrentUser(),
        servicesRepository.getCategories(),
        servicesRepository.getServices(),
      ]);

      final user = results[0] as AppUser?;
      final categories = (results[1] as List<String>?) ?? const <String>[];
      final services = (results[2] as List<Service>?) ?? const <Service>[];
      final featuredServices = services.take(6).toList(growable: false);

      state = state.copyWith(
        user: user,
        categories: categories,
        featured: featuredServices.isEmpty
            ? AsyncState.empty(message: 'Belum ada servis popular.')
            : AsyncState.data(featuredServices),
      );
    } on AppException catch (error) {
      state = state.copyWith(
        featured: AsyncState.error(error: error, message: error.message),
      );
    } catch (error) {
      state = state.copyWith(
        featured: AsyncState.error(
          error: error,
          message: 'Tidak dapat memuatkan dashboard. Sila cuba lagi.',
        ),
      );
    }
  }
}

final homeControllerProvider = StateNotifierProvider.autoDispose<HomeController, HomeState>(
  (ref) {
    return HomeController(
      authRepository: authRepository,
      servicesRepository: servicesRepository,
    );
  },
);
