import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const ProviderScope(child: FreeTaskApp()));
}

final _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
  ],
);

class FreeTaskApp extends StatelessWidget {
  const FreeTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FreeTask App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final timeProvider = Provider<DateTime>((ref) => DateTime.now());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTime = ref.watch(timeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FreeTask Home'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.task_alt, size: 96),
            const SizedBox(height: 16),
            Text(
              'Welcome to FreeTask!'
              '\nCurrent time: '
              '${TimeOfDay.fromDateTime(currentTime).format(context)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Get started building your app!')),
                );
              },
              child: const Text('Show message'),
            ),
          ],
        ),
      ),
    );
  }
}
