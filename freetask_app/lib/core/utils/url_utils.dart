import '../env.dart';

class UrlUtils {
  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    // 1. Rewrite protected paths to public paths (Robust logic)
    // Works for both relative ("/uploads/file.jpg") and absolute ("http://.../uploads/file.jpg")
    String processedUrl = url;
    if (processedUrl.contains('/uploads/') &&
        !processedUrl.contains('/uploads/public/')) {
      processedUrl = processedUrl.replaceFirst('/uploads/', '/uploads/public/');
    }

    // 2. Return absolute URL if already absolute
    if (processedUrl.startsWith('http://') ||
        processedUrl.startsWith('https://')) {
      return processedUrl;
    }

    // 3. Build absolute URL using env default baseUrl
    // Avoid accessing dio.options.baseUrl which may not be initialized yet
    final baseUrl = Env.defaultApiBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final normalizedUrl =
        processedUrl.startsWith('/') ? processedUrl : '/$processedUrl';

    final result = '$normalizedBase$normalizedUrl';
    print('UrlUtils: Resolving "$url" -> "$result"');
    return result;
  }
}
