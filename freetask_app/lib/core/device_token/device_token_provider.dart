abstract class DeviceTokenProvider {
  Future<String?> getDeviceToken();
}

class DummyDeviceTokenProvider implements DeviceTokenProvider {
  const DummyDeviceTokenProvider();

  @override
  Future<String?> getDeviceToken() async {
    return null;
  }
}

/// Placeholder for a future Firebase-backed provider. Replace the
/// implementation once firebase_messaging is available in the project.
class FcmDeviceTokenProvider implements DeviceTokenProvider {
  const FcmDeviceTokenProvider();

  @override
  Future<String?> getDeviceToken() async {
    try {
      final dynamic messaging = await _loadMessaging();
      if (messaging == null) {
        return null;
      }
      final token = await messaging.getToken();
      if (token is String) {
        return token;
      }
      return token?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _loadMessaging() async {
    // Firebase not yet configured; return null to avoid runtime errors.
    return null;
  }
}
