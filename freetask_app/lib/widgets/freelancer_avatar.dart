import 'package:flutter/material.dart';
import '../core/utils/url_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = UrlUtils.resolveImageUrl(avatarUrl);

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage:
            resolvedUrl.isNotEmpty ? NetworkImage(resolvedUrl) : null,
        child: resolvedUrl.isEmpty
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
