import '../core/api/api_client.dart';
import '../models/notification.dart' as models;

class NotificationsRepository {
  final ApiClient _apiClient;

  NotificationsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final notifications = (response.data['notifications'] as List)
        .map((json) => models.Notification.fromJson(json))
        .toList();

    return {
      'notifications': notifications,
      'total': response.data['total'],
      'unreadCount': response.data['unreadCount'],
    };
  }

  Future<models.Notification> markAsRead(int notificationId) async {
    final response = await _apiClient.dio.patch(
      '/notifications/$notificationId/read',
    );

    return models.Notification.fromJson(response.data);
  }

  Future<void> markAllAsRead() async {
    await _apiClient.dio.patch('/notifications/read-all');
  }

  Future<void> registerToken(String token, {String? platform}) async {
    await _apiClient.dio.post(
      '/notifications/register-token',
      data: {
        'token': token,
        'platform': platform ?? 'flutter',
      },
    );
  }

  Future<void> deleteToken(String token) async {
    await _apiClient.dio.delete('/notifications/token/$token');
  }
}

final notificationsRepository = NotificationsRepository();
