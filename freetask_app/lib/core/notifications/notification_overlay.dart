import 'package:flutter/material.dart';

class NotificationOverlay {
  static OverlayEntry? _currentOverlay;
  static final List<OverlayEntry> _queue = [];
  static bool _isShowing = false;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = _createOverlay(
      context: context,
      title: title,
      message: message,
      type: type,
      duration: duration,
    );

    if (_isShowing) {
      _queue.add(overlay);
    } else {
      _showOverlay(context, overlay, duration);
    }
  }

  static OverlayEntry _createOverlay({
    required BuildContext context,
    required String title,
    required String message,
    required NotificationType type,
    required Duration duration,
  }) {
    return OverlayEntry(
      builder: (context) => _NotificationWidget(
        title: title,
        message: message,
        type: type,
        onDismiss: () => _dismissOverlay(context),
      ),
    );
  }

  static void _showOverlay(
    BuildContext context,
    OverlayEntry overlay,
    Duration duration,
  ) {
    _isShowing = true;
    _currentOverlay = overlay;
    Overlay.of(context).insert(overlay);

    Future.delayed(duration, () {
      // Don't use context here - use overlay entry directly
      _currentOverlay?.remove();
      _currentOverlay = null;
      _isShowing = false;

      if (_queue.isNotEmpty) {
        _queue.removeAt(0);
        // Queue processing without context - simplified
      }
    });
  }

  static void _dismissOverlay(BuildContext context) {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _isShowing = false;

    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _showOverlay(context, next, const Duration(seconds: 4));
    }
  }
}

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class _NotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF10B981);
      case NotificationType.error:
        return const Color(0xFFEF4444);
      case NotificationType.warning:
        return const Color(0xFFF59E0B);
      case NotificationType.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 380,
                minWidth: 320,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colored indicator bar
                    Container(
                      width: 5,
                      height: 100,
                      color: _getBackgroundColor(),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getIcon(),
                                  color: _getBackgroundColor(),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _dismiss,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 36),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
