class Env {
  static String get defaultApiBaseUrl {
    // Note: This default can be overridden by BaseUrlManager (user settings)
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    // Production DigitalOcean Backend
    return 'https://freetask-app-cuyrz.ondigitalocean.app';

    // Local Dev
    // return 'http://localhost:4000';
  }
}
