import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_redirect.dart';
import 'auth_repository.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await authRepository.getSavedToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      context.go('/login');
      return;
    }

    try {
      final user = await authRepository.getCurrentUser();
      if (!mounted) {
        return;
      }
      if (user != null) {
        goToRoleHome(context, user.role);
      } else {
        context.go('/login');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menyediakan aplikasi...'),
          ],
        ),
      ),
    );
  }
}
