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
import '../../widgets/notification_bell_button.dart';
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
            appBar: AppBar(
              title: const Text('Chat'),
              actions: const [NotificationBellButton()],
            ),
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
          backgroundColor: const Color(0xFFF5F7FB), // Light Blue-Grey
          appBar: AppBar(
            title: const Text('Chat',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF1976D2), // Primary Blue
            foregroundColor: Colors.white,
            elevation: 0,
            actions: const [NotificationBellButton()],
          ),
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final thread = threads[index];
              final snippet = thread.lastMessage?.isNotEmpty == true
                  ? thread.lastMessage!
                  : 'Tiada mesej lagi.';
              final lastAtLabel = thread.lastAt != null
                  ? DateFormat('dd MMM, h:mm a')
                      .format(thread.lastAt!.toLocal())
                  : '—';

              Color statusColor;
              switch (thread.jobStatus.toUpperCase()) {
                case 'PENDING':
                  statusColor = Colors.orangeAccent;
                  break;
                case 'IN_PROGRESS':
                  statusColor = Colors.lightBlueAccent;
                  break;
                case 'COMPLETED':
                  statusColor = Colors.green;
                  break;
                case 'CANCELLED':
                case 'REJECTED':
                  statusColor = Colors.redAccent;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.push('/chats/${thread.id}/messages');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              const Color(0xFF1976D2).withValues(alpha: 0.1),
                          child: Text(
                            thread.participantName.isNotEmpty
                                ? thread.participantName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.participantName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    lastAtLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                thread.jobTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snippet,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  thread.jobStatus.replaceAll('_', ' '),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: const [NotificationBellButton()],
        ),
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
          appBar: AppBar(
            title: const Text('Chat'),
            actions: const [NotificationBellButton()],
          ),
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
