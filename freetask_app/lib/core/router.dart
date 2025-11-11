import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/chat/chat_list_screen.dart';
import '../features/chat/chat_room_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/jobs/checkout_screen.dart';
import '../features/jobs/job_list_screen.dart';
import '../features/services/service_detail_screen.dart';
import '../features/services/service_list_screen.dart';

final appRouter = GoRouter(
  routes: <RouteBase>[
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
