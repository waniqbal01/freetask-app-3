import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String resolveHomeRouteForRole(String? role) {
  final normalizedRole = role?.toUpperCase();
  switch (normalizedRole) {
    case 'FREELANCER':
      return '/chats'; // Chat is now the default/main screen for all users
    case 'ADMIN':
      return '/admin';
    case 'CLIENT':
      return '/chats'; // Chat is now the default/main screen
    default:
      return '/chats'; // Chat is now the default/main screen
  }
}

void goToRoleHome(BuildContext context, String? role) {
  final targetRoute = resolveHomeRouteForRole(role);
  context.go(targetRoute);
}
