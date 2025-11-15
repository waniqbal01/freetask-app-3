import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String resolveHomeRouteForRole(String? role) {
  switch (role) {
    case 'Freelancer':
      return '/jobs';
    case 'Admin':
      return '/admin';
    case 'Client':
      return '/home';
    default:
      return '/home';
  }
}

void goToRoleHome(BuildContext context, String? role) {
  final targetRoute = resolveHomeRouteForRole(role);
  context.go(targetRoute);
}
