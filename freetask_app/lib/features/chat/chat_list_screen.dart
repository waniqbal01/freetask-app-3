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

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '—';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(timestamp.toLocal());
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEE').format(timestamp); // Mon, Tue, etc.
    } else {
      return DateFormat('dd/MM/yy').format(timestamp);
    }
  }

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

          return Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flash_on,
                      color: Color(0xFF2196F3),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'FreeTask',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: 1.0,
                      fontFamily: 'SF Pro Display',
                    ),
                  ),
                ],
              ),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                const NotificationBellButton(),
                IconButton(
                  icon: const Icon(Icons.account_circle),
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),
            bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2196F3).withOpacity(0.05),
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          size: 64, color: Color(0xFF2196F3)),
                    ),
                    const SizedBox(height: 24),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF128C7E), Color(0xFF075E54)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    color: Color(0xFF2196F3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'FreeTask',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    letterSpacing: 1.0,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ],
            ),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              const NotificationBellButton(),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: threads.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (BuildContext context, int index) {
              final thread = threads[index];
              final snippet = thread.lastMessage?.isNotEmpty == true
                  ? thread.lastMessage!
                  : 'Tiada mesej lagi.';
              final lastAtLabel = _formatTimestamp(thread.lastAt);

              Color statusColor;
              switch (thread.jobStatus.toUpperCase()) {
                case 'PENDING':
                  statusColor = Colors.orange;
                  break;
                case 'IN_PROGRESS':
                  statusColor = const Color(0xFF2196F3);
                  break;
                case 'COMPLETED':
                  statusColor = Colors.green;
                  break;
                case 'CANCELLED':
                case 'REJECTED':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => context.push('/chats/${thread.id}/messages'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with gradient border (WhatsApp style)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withOpacity(0.6),
                                statusColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              thread.participantName.isNotEmpty
                                  ? thread.participantName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    lastAtLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                thread.jobTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      snippet,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      thread.jobStatus
                                          .replaceAll('_', ' ')
                                          .toLowerCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: statusColor.withOpacity(0.9),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  // Unread badge
                                  if (thread.unreadCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: const BoxDecoration(
                                        color:
                                            Color(0xFF25D366), // WhatsApp green
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      child: Center(
                                        child: Text(
                                          thread.unreadCount > 99
                                              ? '99+'
                                              : '${thread.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('FreeTask'),
          foregroundColor: Colors.white,
          actions: [
            const NotificationBellButton(),
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
        body: const Center(
            child: CircularProgressIndicator(
          color: Color(0xFF128C7E),
        )),
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
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: const Text('FreeTask'),
            foregroundColor: Colors.white,
            actions: [
              const NotificationBellButton(),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 42, color: Color(0xFFDC4E41)),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
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
