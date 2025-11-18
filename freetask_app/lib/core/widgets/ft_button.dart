import 'package:flutter/material.dart';

enum FTButtonSize { small, medium, large }

class FTButton extends StatelessWidget {
  const FTButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.expanded = true,
    this.size = FTButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expanded;
  final FTButtonSize size;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final horizontalPadding = switch (size) {
      FTButtonSize.small => 12.0,
      FTButtonSize.medium => 20.0,
      FTButtonSize.large => 24.0,
    };

    final verticalPadding = switch (size) {
      FTButtonSize.small => 12.0,
      FTButtonSize.medium => 16.0,
      FTButtonSize.large => 18.0,
    };

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: child,
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
