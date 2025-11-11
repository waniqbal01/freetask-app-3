import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'chat_repository.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(chatThreadsProvider);

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
  }
}
