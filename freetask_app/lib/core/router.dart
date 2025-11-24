import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/auth/startup_screen.dart';
import '../features/chat/chat_list_screen.dart';
import '../features/chat/chat_room_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/jobs/checkout_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/job_list_screen.dart';
import '../features/settings/api_settings_screen.dart';
import '../features/services/service_detail_screen.dart';
import '../features/services/service_list_screen.dart';
import '../models/job.dart';
import '../features/auth/auth_repository.dart';
import 'notifications/notification_service.dart';
import 'storage/storage.dart';
import 'utils/query_utils.dart';

final authRefreshNotifier = ValueNotifier<DateTime>(DateTime.now());
final AppStorage _storage = appStorage;

Future<bool> hasToken() async {
  final token = await _storage.read(AuthRepository.tokenStorageKey);
  if (token != null && token.isNotEmpty) {
    return true;
  }

  final legacy = await _storage.read(AuthRepository.legacyTokenStorageKey);
  if (legacy != null && legacy.isNotEmpty) {
    await _storage.write(AuthRepository.tokenStorageKey, legacy);
    await _storage.delete(AuthRepository.legacyTokenStorageKey);
    return true;
  }

  return false;
}

final appRouter = GoRouter(
  initialLocation: '/startup',
  refreshListenable: authRefreshNotifier,
  redirect: (context, state) async {
    final location = state.uri.path;
    final isAuthPage = ['/login', '/register', '/role-selection'].contains(location);
    final isStartup = location == '/startup' || location == '/';
    final needsAuth =
        location.startsWith('/jobs') || location.startsWith('/chats') || location.startsWith('/admin');

    final tokenExists = await hasToken();

    if (!tokenExists && needsAuth) {
      return '/login';
    }

    if (tokenExists && (isAuthPage || isStartup)) {
      return '/home';
    }

    if (location.startsWith('/admin')) {
      try {
        final user = await authRepository.getCurrentUser();
        if (user == null) {
          return '/login';
        }
        if (user.role.toUpperCase() != 'ADMIN') {
          return '/home';
        }
      } catch (_) {
        return '/login';
      }
    }

    if (location.startsWith('/jobs')) {
      final filter = state.uri.queryParameters['filter'];
      if (filter == 'all') {
        final user = await authRepository.getCurrentUser();
        if (user == null) {
          return '/login';
        }
        if (user.role.toUpperCase() != 'ADMIN') {
          notificationService.messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Access denied')),
          );
          return '/jobs';
        }
      }
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/startup',
      builder: (BuildContext context, GoRouterState state) {
        return const StartupScreen();
      },
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const RoleSelectionScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        final roleFromQuery = state.uri.queryParameters['role'];
        final role = (state.extra ?? roleFromQuery) as String?;
        return RegisterScreen(role: role);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) {
        return const ServiceListScreen();
      },
    ),
    GoRoute(
      path: '/service/:id',
      builder: (BuildContext context, GoRouterState state) {
        final serviceId = state.pathParameters['id'] ?? 'unknown';
        return ServiceDetailScreen(serviceId: serviceId);
      },
    ),
    GoRoute(
      path: '/chats',
      builder: (BuildContext context, GoRouterState state) {
        final limit = parsePositiveInt(state.uri.queryParameters['limit']);
        final offset = parsePositiveInt(state.uri.queryParameters['offset']);
        return ChatListScreen(
          limitQuery: limit?.toString(),
          offsetQuery: offset?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/chats/:jobId/messages',
      builder: (BuildContext context, GoRouterState state) {
        final chatId = state.pathParameters['jobId'] ?? 'unknown';
        return ChatRoomScreen(chatId: chatId);
      },
    ),
    GoRoute(
      path: '/jobs',
      builder: (BuildContext context, GoRouterState state) {
        final limit = parsePositiveInt(state.uri.queryParameters['limit']);
        final offset = parsePositiveInt(state.uri.queryParameters['offset']);
        return JobListScreen(
          limitQuery: limit?.toString(),
          offsetQuery: offset?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (BuildContext context, GoRouterState state) {
        final extras = state.extra as Map<String, dynamic>?;
        final job = extras?['job'] as Job?;
        final isClientView = extras?['isClientView'] as bool?;
        final jobId = state.pathParameters['id'] ?? 'unknown';
        return JobDetailScreen(
          jobId: jobId,
          initialJob: job,
          isClientView: isClientView,
        );
      },
    ),
    GoRoute(
      path: '/jobs/checkout',
      builder: (BuildContext context, GoRouterState state) {
        final summary = state.extra as Map<String, dynamic>?;
        return JobCheckoutScreen(serviceSummary: summary);
      },
    ),
    GoRoute(
      path: '/checkout',
      builder: (BuildContext context, GoRouterState state) {
        final jobDraft = state.extra as Map<String, dynamic>?;
        return CheckoutScreen(jobDraft: jobDraft);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminDashboardScreen();
      },
    ),
    GoRoute(
      path: '/settings/api',
      builder: (BuildContext context, GoRouterState state) {
        return const ApiSettingsScreen();
      },
    ),
  ],
);
