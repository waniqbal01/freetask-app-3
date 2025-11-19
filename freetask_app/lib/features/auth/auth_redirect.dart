import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String resolveHomeRouteForRole(String? role) {
  final normalizedRole = role?.toUpperCase();
  switch (normalizedRole) {
    case 'FREELANCER':
      return '/home';
    case 'ADMIN':
      return '/admin';
    case 'CLIENT':
      return '/home';
    default:
      return '/home';
  }
}

void goToRoleHome(BuildContext context, String? role) {
  final targetRoute = resolveHomeRouteForRole(role);
  context.go(targetRoute);
}
