import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class FreelancerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final VoidCallback? onTap;

  const FreelancerAvatar({
    this.avatarUrl,
    this.size = 40,
    this.onTap,
    super.key,
  });

  String _getAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;

    // Convert relative URL to absolute
    final apiUrl = ApiClient().baseUrl;
    return '$apiUrl$url';
  }

  @override
  Widget build(BuildContext context) {
    final absoluteUrl = _getAbsoluteUrl(avatarUrl);

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage:
            absoluteUrl.isNotEmpty ? NetworkImage(absoluteUrl) : null,
        child: absoluteUrl.isEmpty
            ? Icon(
                Icons.person,
                size: size * 0.6,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )
            : null,
      ),
    );
  }
}
