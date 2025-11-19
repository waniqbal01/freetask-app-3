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
import '../features/home/home_screen.dart';
import '../features/jobs/checkout_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/job_list_screen.dart';
import '../features/services/my_services_screen.dart';
import '../features/services/service_detail_screen.dart';
import '../features/services/service_form_screen.dart';
import '../features/services/service_list_screen.dart';
import '../models/job.dart';
import '../models/service.dart';

final appRouter = GoRouter(
  initialLocation: '/startup',
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
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/services',
      builder: (BuildContext context, GoRouterState state) {
        final category = state.uri.queryParameters['category'];
        final query = state.uri.queryParameters['q'];
        return ServiceListScreen(
          initialCategory: category,
          initialQuery: query,
        );
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
      path: '/freelancer/services',
      builder: (BuildContext context, GoRouterState state) {
        return const MyServicesScreen();
      },
    ),
    GoRoute(
      path: '/freelancer/services/new',
      builder: (BuildContext context, GoRouterState state) {
        return const ServiceFormScreen();
      },
    ),
    GoRoute(
      path: '/freelancer/services/:id/edit',
      builder: (BuildContext context, GoRouterState state) {
        final serviceId = state.pathParameters['id'];
        final service = state.extra as Service?;
        return ServiceFormScreen(
          serviceId: serviceId,
          initialService: service,
        );
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (BuildContext context, GoRouterState state) {
        return const ChatListScreen();
      },
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (BuildContext context, GoRouterState state) {
        final chatId = state.pathParameters['id'] ?? 'unknown';
        return ChatRoomScreen(chatId: chatId);
      },
    ),
    GoRoute(
      path: '/jobs',
      builder: (BuildContext context, GoRouterState state) {
        return const JobListScreen();
      },
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (BuildContext context, GoRouterState state) {
        final extras = state.extra as Map<String, dynamic>?;
        final job = extras?['job'] as Job?;
        final isClientView = extras?['isClientView'] as bool? ?? true;

        if (job == null) {
          return const Scaffold(
            body: Center(
              child: Text('Maklumat job tidak tersedia.'),
            ),
          );
        }

        return JobDetailScreen(job: job, isClientView: isClientView);
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
  ],
);
