import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../models/user.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/auth_repository.dart';

final _currentUserProvider = FutureProvider<AppUser?>((ref) async {
  try {
    return authRepository.getCurrentUser();
  } catch (_) {
    return null;
  }
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key, this.limitQuery, this.offsetQuery});

  final String? limitQuery;
  final String? offsetQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_currentUserProvider);
    final role = userAsync.asData?.value?.role.toUpperCase();
    final threadsAsync = ref.watch(
      chatThreadsProviderWithQuery((limit: limitQuery, offset: offsetQuery)),
    );

    return threadsAsync.when(
      data: (List<ChatThread> threads) {
        if (threads.isEmpty) {
          // UX-G-07: Role-aware chat empty state
          final isClient = role == 'CLIENT';
          final title = isClient
              ? 'Belum ada chat lagi.'
              : 'Belum ada chat sebagai freelancer.';
          final subtitle = isClient
              ? 'Chat akan muncul apabila anda menempah servis atau memulakan job dengan freelancer.'
              : 'Chat akan muncul apabila client menempah servis anda atau memberikan job kepada anda.';
          final primaryCta = isClient
              ? 'Pergi ke Home untuk cari servis'
              : 'Pergi ke Job Board';
          final primaryAction =
              isClient ? () => context.go('/home') : () => context.go('/jobs');
          final secondaryLabel =
              isClient ? 'Lihat servis' : 'Pergi ke Servis saya';
          void secondaryAction() => context.go('/home');

          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(title),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: primaryAction,
                    icon: const Icon(Icons.search),
                    label: Text(primaryCta),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: secondaryAction,
                    icon:
                        Icon(isClient ? Icons.store_mall_directory : Icons.add),
                    label: Text(secondaryLabel),
                  ),
                  TextButton(
                    onPressed: () => ref.refresh(
                      chatThreadsProviderWithQuery(
                        (limit: limitQuery, offset: offsetQuery),
                      ),
                    ),
                    child: const Text('Muat Semula'),
                  )
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final thread = threads[index];
              final snippet = thread.lastMessage?.isNotEmpty == true
                  ? thread.lastMessage!
                  : 'Tiada mesej lagi.';
              final lastAtLabel = thread.lastAt != null
                  ? DateFormat('dd MMM, h:mm a')
                      .format(thread.lastAt!.toLocal())
                  : '—';
              return ListTile(
                title: Text(thread.jobTitle),
                subtitle: Text(
                  '${thread.participantName} · $snippet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lastAtLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  context.push('/chats/${thread.id}/messages');
                },
              );
            },
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) {
        final message = error is DioException
            ? resolveDioErrorMessage(error)
            : 'Chat akan datang (Coming Soon). Sila cuba lagi nanti.';
        if (error is DioException) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            if (messenger != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          });
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 42, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.refresh(
                      chatThreadsProviderWithQuery(
                        (limit: limitQuery, offset: offsetQuery),
                      ),
                    ),
                    child: const Text('Cuba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
