import 'env.dart';

class AppInfo {
  static const bool isDev = bool.fromEnvironment('IS_DEV', defaultValue: true);
  static const String environmentLabel =
      String.fromEnvironment('APP_ENV', defaultValue: isDev ? 'DEV' : 'STAGING');
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');

  static String get apiBaseUrl => Env.apiBaseUrl;
}
