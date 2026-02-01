class Env {
  static String get defaultApiBaseUrl {
    // Note: This default can be overridden by BaseUrlManager (user settings)
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    // Live Render Backend (Updated to match actual Render service URL)
    return 'https://freetask-api.onrender.com';

    // Local Dev
    // return 'http://localhost:4000';
  }
}
