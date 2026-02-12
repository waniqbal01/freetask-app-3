/// Environment configuration for the app
class AppConfig {
  // Note: Actual API base URL is managed by BaseUrlStore
  // This WebSocket URL will be used when feature flag is enabled

  // WebSocket URL (will use same as API URL when backend ready)
  static String websocketUrlFromApi(String apiUrl) {
    return apiUrl.replaceAll('/api', '');
  }

  // Feature flags - ENABLED FOR PRODUCTION!
  static const bool useWebSocket = true;

  static const bool enableTypingIndicators = true;

  static const bool showOnlineStatus = true;
}
