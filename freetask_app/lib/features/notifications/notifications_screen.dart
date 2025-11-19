import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/error_utils.dart';
import '../../core/widgets/ft_button.dart';
import 'app_notification.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.when(
        data: (List<AppNotification> notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('Tiada notifikasi buat masa ini.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemBuilder: (BuildContext context, int index) {
                final notification = notifications[index];
                return _NotificationTile(notification: notification);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: notifications.length,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) {
          final message = friendlyErrorMessage(error);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FTButton(
                    label: 'Cuba Lagi',
                    onPressed: () =>
                        ref.read(notificationsControllerProvider.notifier).load(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = DateFormat('dd MMM, h:mm a');
    final textTheme = Theme.of(context).textTheme;
    final timestamp = formatter.format(notification.createdAt.toLocal());
    final colorScheme = Theme.of(context).colorScheme;
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () => ref
          .read(notificationsControllerProvider.notifier)
          .markAsRead(notification.id)
          .catchError((Object error) {
        showErrorSnackBar(context, error);
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? colorScheme.primary.withOpacity(0.05)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? colorScheme.primary.withOpacity(0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(notification.body),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  notification.type,
                  style: textTheme.labelSmall,
                ),
                Text(
                  timestamp,
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
