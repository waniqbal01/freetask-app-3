import 'package:flutter/material.dart';

import '../services/upload_service.dart';

class AuthorizedImage extends StatelessWidget {
  const AuthorizedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  Future<({String url, Map<String, String> headers})> _resolve() async {
    final resolvedUrl = await uploadService.resolveAuthorizedUrl(url);
    final headers = await uploadService.authorizationHeader();
    return (url: resolvedUrl, headers: headers);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String url, Map<String, String> headers})>(
      future: _resolve(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder ?? _fallbackContainer();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return placeholder ??
              _fallbackContainer(icon: Icons.image_not_supported_outlined);
        }

        final data = snapshot.data!;
        final image = Image.network(
          data.url,
          width: width,
          height: height,
          fit: fit,
          headers: data.headers.isEmpty ? null : data.headers,
          errorBuilder: (_, __, ___) =>
              placeholder ??
              _fallbackContainer(icon: Icons.image_not_supported_outlined),
        );

        if (borderRadius == null) {
          return image;
        }

        return ClipRRect(
          borderRadius: borderRadius!,
          child: image,
        );
      },
    );
  }

  Widget _fallbackContainer({IconData icon = Icons.image_rounded}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.grey.shade500),
    );
  }
}
