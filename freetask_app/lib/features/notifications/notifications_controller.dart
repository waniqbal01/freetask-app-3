import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_notification.dart';
import 'notifications_repository.dart';

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<List<AppNotification>>>(
  (Ref ref) {
    final controller = NotificationsController(ref.watch(notificationRepositoryProvider));
    controller.load();
    return controller;
  },
);

final unreadNotificationsCountProvider = Provider<int>((Ref ref) {
  final state = ref.watch(notificationsControllerProvider);
  return state.maybeWhen(
    data: (List<AppNotification> notifications) =>
        notifications.where((AppNotification n) => !n.isRead).length,
    orElse: () => 0,
  );
});

class NotificationsController
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsController(this._repository)
      : super(const AsyncValue.loading());

  final NotificationRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.fetchNotifications);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.fetchNotifications);
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
      state = state.whenData((List<AppNotification> notifications) {
        return notifications
            .map(
              (AppNotification notification) => notification.id == id
                  ? notification.copyWith(isRead: true)
                  : notification,
            )
            .toList(growable: false);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
