import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/user.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/notification_bell_button.dart';
import '../auth/auth_repository.dart';

final _currentUserProvider = FutureProvider.autoDispose<AppUser?>((ref) async {
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
    return TimeUtils.formatChatListTime(timestamp);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_currentUserProvider);
    final role = userAsync.asData?.value?.role.toUpperCase();
    final repo = ref.watch(chatRepositoryProvider);
    final threadsAsync = ref.watch(
      chatThreadsProviderWithQuery((limit: limitQuery, offset: offsetQuery)),
    );

    final List<ChatThread>? rawThreads = repo.currentThreads.isNotEmpty
        ? repo.currentThreads
        : threadsAsync.value;

    final List<ChatThread>? threads = rawThreads
        ?.where((t) => t.lastMessage != null && t.lastMessage!.isNotEmpty)
        .toList();

    if (threads != null) {
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
          backgroundColor: Colors.white,
          bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ChatHeader(
                  userName: userAsync.asData?.value?.name,
                  onSearchTap: () => _showSearch(context, ref),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(
                              Icons.store_mall_directory_outlined,
                            ),
                            label: Text(
                              isClient
                                  ? 'Cari Freelancer Sekarang'
                                  : 'Terokai Marketplace',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chats),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              chatThreadsProviderWithQuery(
                (limit: limitQuery, offset: offsetQuery),
              ),
            );
          },
          child: CustomScrollView(
            slivers: [
              // Services-style gradient header
              SliverToBoxAdapter(
                child: _ChatHeader(
                  userName: userAsync.asData?.value?.name,
                  onSearchTap: () => _showSearch(context, ref),
                ),
              ),
              // Chat list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final thread = threads[index];
                    final snippet = thread.lastMessage?.isNotEmpty == true
                        ? thread.lastMessage!
                        : 'Tiada mesej lagi.';
                    final lastAtLabel = _formatTimestamp(thread.lastAt);

                    Color statusColor;
                    // Determine status color based on thread status
                    // 'ACTIVE' is the default for normal conversations
                    switch (thread.status.toUpperCase()) {
                      case 'PENDING':
                        statusColor = Colors.orange;
                        break;
                      case 'IN_PROGRESS':
                      case 'ACTIVE':
                        statusColor = const Color(0xFF2196F3);
                        break;
                      case 'COMPLETED':
                        statusColor = Colors.green;
                        break;
                      case 'CANCELLED':
                      case 'REJECTED':
                      case 'ARCHIVED':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => context.push(
                          '/chats/${thread.id}/messages',
                          extra: thread,
                        ),
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
                                  backgroundImage:
                                      (thread.participantAvatarUrl != null &&
                                              thread.participantAvatarUrl!
                                                  .isNotEmpty)
                                          ? NetworkImage(
                                              UrlUtils.resolveImageUrl(
                                                  thread.participantAvatarUrl),
                                            )
                                          : null,
                                  child: (thread.participantAvatarUrl != null &&
                                          thread
                                              .participantAvatarUrl!.isNotEmpty)
                                      ? null
                                      : Text(
                                          thread.participantName.isNotEmpty
                                              ? thread.participantName[0]
                                                  .toUpperCase()
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
                                      thread.title,
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
                                            color:
                                                statusColor.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color:
                                                  statusColor.withOpacity(0.3),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            thread.status
                                                .replaceAll('_', ' ')
                                                .toLowerCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color:
                                                  statusColor.withOpacity(0.9),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        // Unread badge (red circle like WhatsApp)
                                        if (thread.unreadCount > 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: const BoxDecoration(
                                              color: Color(
                                                  0xFFE53935), // Red badge
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
                  childCount: threads.length,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return threadsAsync.when(
      data: (_) => const SizedBox.shrink(), // Fallback (shouldn't be reached)
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
          color: Color(0xFF2196F3),
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

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _ChatSearchDelegate(ref: ref),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.userName,
    required this.onSearchTap,
  });

  final String? userName;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          width: double.infinity,
          height: 260,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Badge & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Name
                    const Text(
                      'freetask',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const NotificationBellButton(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.account_circle,
                                color: Colors.white),
                            onPressed: () => context.push('/profile'),
                            tooltip: 'Profile',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Personalized Greeting
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hello, ',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                      TextSpan(
                        text: userName?.split(' ').first ?? 'Tetamu',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uruskan projek anda dengan freelancer yang tepat.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Overlapping Search Card
        Container(
          margin:
              const EdgeInsets.only(top: 220, left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle Buttons
              Row(
                children: [
                  // Chat Button (Active)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            color: Color(0xFF2196F3),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chat',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: const Color(0xFF2196F3),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Marketplace Button (Inactive)
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go('/home'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_mall_directory_outlined,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Marketplace',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar
              InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        'Cari chat...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  _ChatSearchDelegate({required this.ref});

  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Cari chat...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Cari chat anda',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final threadsAsync = ref.watch(chatThreadsProvider);

    return threadsAsync.when(
      data: (threads) {
        final filtered = threads.where((thread) {
          if (thread.lastMessage == null || thread.lastMessage!.isEmpty) {
            return false;
          }
          final searchLower = query.toLowerCase();
          return thread.participantName.toLowerCase().contains(searchLower) ||
              thread.title.toLowerCase().contains(searchLower) ||
              thread.lastMessage!.toLowerCase().contains(searchLower);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Tiada hasil untuk "$query"',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final thread = filtered[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF2196F3).withOpacity(0.2),
                backgroundImage: (thread.participantAvatarUrl != null &&
                        thread.participantAvatarUrl!.isNotEmpty)
                    ? NetworkImage(
                        UrlUtils.resolveImageUrl(thread.participantAvatarUrl),
                      )
                    : null,
                child: (thread.participantAvatarUrl != null &&
                        thread.participantAvatarUrl!.isNotEmpty)
                    ? null
                    : Text(
                        thread.participantName.isNotEmpty
                            ? thread.participantName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              title: Text(thread.participantName),
              subtitle: Text(thread.title),
              onTap: () {
                close(context, '');
                context.push('/chats/${thread.id}/messages');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Ralat memuatkan chat'),
      ),
    );
  }
}
