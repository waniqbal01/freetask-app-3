import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminUnauthorizedScreen extends StatelessWidget {
  const AdminUnauthorizedScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.privacy_tip_outlined,
                        size: 64, color: Colors.indigo),
                    const SizedBox(height: 16),
                    Text(
                      'Access terhad',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Akaun anda bukan admin. Jika anda rasa ini kesilapan, sila hubungi support.',
                      textAlign: TextAlign.center,
                    ),
                    if (from != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'URL diminta: $from',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Kembali ke Home'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
