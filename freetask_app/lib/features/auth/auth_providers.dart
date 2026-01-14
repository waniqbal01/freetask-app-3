import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import '../../models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return authRepository;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});
