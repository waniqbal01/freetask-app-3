class Env {
  static String get defaultApiBaseUrl {
    // Note: This default can be overridden by BaseUrlManager (user settings)
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) return envOverride;

    // Local development - backend running with npm run start:dev
    return 'http://localhost:4000';

    // Production Render Backend (uncomment when deploying)
    // return 'https://freetask-backend.onrender.com';
  }
}
