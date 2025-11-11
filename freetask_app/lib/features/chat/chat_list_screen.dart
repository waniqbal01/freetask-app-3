import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'chat_repository.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);

    return threadsAsync.when(
      data: (List<ChatThread> threads) {
        if (threads.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: const Center(child: Text('Tiada chat buat masa ini.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: ListView.separated(
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
        );
      },
      loading: () => const Scaffold(
        appBar: AppBar(title: Text('Chat')),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(child: Text('Ralat memuat chat: $error')),
      ),
    );
  }
}
