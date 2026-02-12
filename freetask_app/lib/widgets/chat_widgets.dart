import 'package:flutter/material.dart';
import '../../models/chat_enums.dart';

/// Widget to display message status icon based on MessageStatus
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    this.size = 16,
  });

  final MessageStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.pending:
        return Icon(
          Icons.access_time,
          size: size * 0.875, // Slightly smaller
          color: Colors.grey.shade400,
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done,
          size: size,
          color: Colors.grey.shade500,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: size,
          color: Colors.grey.shade500,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: size,
          color: Colors.blue.shade600,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: size,
          color: Colors.red.shade400,
        );
    }
  }
}

/// Animated typing indicator (three bouncing dots)
class TypingAnimation extends StatefulWidget {
  const TypingAnimation({
    super.key,
    this.size = 6.0,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<TypingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? Colors.grey.shade600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value - delay) % 1.0;
            final bounce = value < 0.5
                ? Curves.easeOut.transform(value * 2)
                : Curves.easeIn.transform((1 - value) * 2);

            return Transform.translate(
              offset: Offset(0, -bounce * widget.size),
              child: child,
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

/// Connection status banner widget
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.status,
  });

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    String message;
    Widget? trailing;

    switch (status) {
      case ConnectionStatus.connecting:
        backgroundColor = Colors.orange.shade100;
        message = 'Menyambung...';
        trailing = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange.shade700,
          ),
        );
        break;
      case ConnectionStatus.reconnecting:
        backgroundColor = Colors.amber.shade100;
        message = 'Menyambung semula...';
        trailing = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.amber.shade700,
          ),
        );
        break;
      case ConnectionStatus.disconnected:
        backgroundColor = Colors.red.shade100;
        message = 'Tiada sambungan';
        trailing = Icon(
          Icons.cloud_off,
          size: 16,
          color: Colors.red.shade700,
        );
        break;
      case ConnectionStatus.connected:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
