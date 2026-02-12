import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_unauthorized_screen.dart';
import '../features/admin/new_admin_dashboard_screen.dart';
import '../features/admin/bank_verification/admin_bank_verification_screen.dart';
import '../features/admin/admin_repository.dart';
import '../services/http_client.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/startup_screen.dart';

import '../features/chat/chat_list_screen.dart';
import '../features/chat/chat_room_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/jobs/checkout_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/job_list_screen.dart';
import '../features/users/profile_screen.dart';
import '../features/services/service_detail_screen.dart';
import '../features/services/service_list_screen.dart';
import '../features/users/public_profile_screen.dart';
import '../features/services/create_service_screen.dart';
import '../features/services/edit_service_screen.dart';
import '../features/withdrawals/withdrawal_screen.dart';
import '../models/service.dart';

import '../models/job.dart';
import '../features/auth/auth_repository.dart';
import 'notifications/notification_service.dart';
import 'storage/storage.dart';
import 'utils/query_utils.dart';
import '../features/jobs/filtered_job_list_screen.dart';

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
  initialLocation: '/',
  refreshListenable: authRefreshNotifier,
  redirect: (context, state) async {
    final location = state.uri.path;
    final isAuthPage =
        ['/login', '/register', '/role-selection'].contains(location);
    final isStartup = location == '/startup' || location == '/';
    final isAdminUnauthorized = location == '/admin/unauthorized';
    final needsAuth = location.startsWith('/jobs') ||
        location.startsWith('/chats') ||
        location.startsWith('/admin') ||
        location.startsWith('/profile');
    final tokenExists = await hasToken();

    // Fix UX-G-01: Prioritize auth status over onboarding flag
    // Onboarding section removed per user request

    if (!tokenExists && needsAuth) {
      final encoded = Uri.encodeComponent(state.uri.toString());
      return '/login?returnTo=$encoded';
    }

    if (tokenExists && (isAuthPage || isStartup)) {
      final returnTo = state.uri.queryParameters['returnTo'];
      if (returnTo != null && returnTo.isNotEmpty) {
        return returnTo;
      }
      return '/chats'; // Chat is now the default/main screen
    }

    // Only validate admin role when accessing admin routes
    if (location.startsWith('/admin') && !isAdminUnauthorized) {
      try {
        final user = await authRepository.getCurrentUser();
        if (user == null) {
          return '/login';
        }
        if (user.role.toUpperCase() != 'ADMIN') {
          final encoded = Uri.encodeComponent(state.uri.toString());
          return '/admin/unauthorized?from=$encoded';
        }
      } catch (_) {
        return '/login';
      }
    }

    // Admin filter validation for all jobs
    if (location.startsWith('/jobs')) {
      final filter = state.uri.queryParameters['filter'];
      if (filter == 'all') {
        try {
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
        } catch (_) {
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
        return LoginScreen(returnTo: state.uri.queryParameters['returnTo']);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        final returnTo = state.uri.queryParameters['returnTo'];
        return LoginScreen(returnTo: returnTo);
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
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen();
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
      path: '/services/create',
      builder: (BuildContext context, GoRouterState state) {
        return const CreateServiceScreen();
      },
    ),
    GoRoute(
      path: '/services/:id/edit',
      builder: (BuildContext context, GoRouterState state) {
        final service = state.extra as Service?;
        if (service == null) {
          // Fallback to home if no service provided
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return EditServiceScreen(service: service);
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
      path: '/job-checkout',
      builder: (BuildContext context, GoRouterState state) {
        final summary = state.extra as Map<String, dynamic>?;
        return JobCheckoutScreen(serviceSummary: summary);
      },
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (BuildContext context, GoRouterState state) {
        final extras = state.extra as Map<String, dynamic>?;
        final job = extras?['job'] as Job?;
        final isClientView = extras?['isClientView'] as bool?;
        final fromCheckout = extras?['fromCheckout'] as bool?; // UX-C-05
        final jobId = state.pathParameters['id'] ?? 'unknown';
        return JobDetailScreen(
          jobId: jobId,
          initialJob: job,
          isClientView: isClientView,
          fromCheckout: fromCheckout,
        );
      },
    ),
    GoRoute(
      path: '/jobs/filtered',
      builder: (BuildContext context, GoRouterState state) {
        final title = state.uri.queryParameters['title'] ?? 'Jobs';
        final role = state.uri.queryParameters['role'] ?? 'client';
        final statuses =
            state.uri.queryParameters['statuses']?.split(',') ?? [];
        return FilteredJobListScreen(
            title: title, role: role, statuses: statuses);
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
        return const NewAdminDashboardScreen(); // Use new comprehensive dashboard
      },
    ),
    GoRoute(
      path: '/admin/old',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminDashboardScreen(); // Old dashboard still available
      },
    ),
    GoRoute(
      path: '/admin/unauthorized',
      builder: (BuildContext context, GoRouterState state) {
        final from = state.uri.queryParameters['from'];
        return AdminUnauthorizedScreen(from: from);
      },
    ),
    GoRoute(
      path: '/admin/bank-verification',
      builder: (BuildContext context, GoRouterState state) {
        // We need an instance of AdminRepository here.
        // Ideally we use dependency injection or a provider, but for now we create one with the default client.
        // Or we pass it from the dashboard if we nested the routes.
        // Given the simplistic DI here:
        final httpClient = HttpClient();
        final repo = AdminRepository(dio: httpClient.dio);
        return AdminBankVerificationScreen(adminRepository: repo);
      },
    ),
    GoRoute(
      path: '/withdrawals',
      builder: (BuildContext context, GoRouterState state) {
        return const WithdrawalScreen();
      },
    ),
    GoRoute(
      path: '/users/:id',
      builder: (BuildContext context, GoRouterState state) {
        final userId = state.pathParameters['id'] ?? 'unknown';
        return PublicProfileScreen(userId: userId);
      },
    ),
  ],
);
