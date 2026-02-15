import '../env.dart';

class UrlUtils {
  static String? _dynamicBaseUrl;

  static void setDynamicBaseUrl(String url) {
    if (url.isNotEmpty) {
      _dynamicBaseUrl = url;
    }
  }

  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    // 1. Return absolute URL if already absolute (prioritize external/Supabase URLs)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 2. Rewrite protected paths to public paths (Only for local paths)
    String processedUrl = url;
    if (processedUrl.contains('/uploads/') &&
        !processedUrl.contains('/uploads/public/')) {
      processedUrl = processedUrl.replaceFirst('/uploads/', '/uploads/public/');
    }

    // 3. Build absolute URL using dynamic base url or env default
    final baseUrl = _dynamicBaseUrl ?? Env.defaultApiBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final normalizedUrl =
        processedUrl.startsWith('/') ? processedUrl : '/$processedUrl';

    final result = '$normalizedBase$normalizedUrl';
    // Remove print to reduce noise, or keep for debugging
    // print('UrlUtils: Resolving "$url" -> "$result"');
    return result;
  }
}
