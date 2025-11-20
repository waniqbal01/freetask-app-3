import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    Future<void> refresh() => ref.refresh(chatThreadsProvider.future);

    return threadsAsync.when(
      data: (List<ChatThread> threads) {
        if (threads.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'Tiada chat lagi. Cipta job daripada senarai servis untuk memulakan perbualan.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/services'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Buka Marketplace Servis'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final thread = threads[index];
                return ListTile(
                  title: Text(thread.jobTitle),
                  subtitle: Text('Pengguna: ${thread.participantName}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/chat/${thread.id}');
                  },
                );
              },
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(friendlyErrorMessage(error))),
            );
          }
        });
        return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                const SizedBox(height: 120),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_tethering_error_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak dapat memuatkan chat sekarang. Sila tarik untuk segar semula atau semak sambungan/token anda.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('Cuba lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
