/// Environment configuration for the app
class AppConfig {
  // Note: Actual API base URL is managed by BaseUrlStore
  // This WebSocket URL will be used when feature flag is enabled

  // WebSocket URL (will use same as API URL when backend ready)
  static String websocketUrlFromApi(String apiUrl) {
    return apiUrl.replaceAll('/api', '');
  }

  // Feature flags - Set to true when backend WebSocket is ready
  static const bool useWebSocket =
      false; // TODO: Set to true when backend ready

  static const bool enableTypingIndicators =
      false; // TODO: Set to true when backend ready

  static const bool showOnlineStatus =
      false; // TODO: Set to true when backend ready
}
