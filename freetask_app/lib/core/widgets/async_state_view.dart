import 'package:flutter/material.dart';

import '../state/async_state.dart';
import '../utils/error_utils.dart';

typedef AsyncDataBuilder<T> = Widget Function(BuildContext context, T data);
typedef AsyncMessageBuilder = Widget Function(
  BuildContext context,
  String message,
  VoidCallback? onRetry,
);

typedef AsyncEmptyBuilder = Widget Function(BuildContext context, String message);

typedef AsyncLoadingBuilder = Widget Function(BuildContext context);

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.state,
    required this.data,
    this.loading,
    this.empty,
    this.error,
    this.onRetry,
    this.customEmptyCheck,
    super.key,
  });

  final AsyncState<T> state;
  final AsyncDataBuilder<T> data;
  final AsyncLoadingBuilder? loading;
  final AsyncEmptyBuilder? empty;
  final AsyncMessageBuilder? error;
  final VoidCallback? onRetry;
  final bool Function(T data)? customEmptyCheck;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return loading?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    if (state.hasError) {
      final message = state.message ?? friendlyErrorMessage(state.error);
      return error?.call(context, message, onRetry) ??
          _DefaultError(message: message, onRetry: onRetry);
    }

    final dataValue = state.data;
    if (state.isEmpty || dataValue == null) {
      final message = state.message ?? 'Tiada data buat masa ini.';
      return empty?.call(context, message) ?? _DefaultEmpty(message: message);
    }

    if (customEmptyCheck?.call(dataValue) == true) {
      final message = state.message ?? 'Tiada data buat masa ini.';
      return empty?.call(context, message) ?? _DefaultEmpty(message: message);
    }

    return data(context, dataValue);
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Cuba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DefaultEmpty extends StatelessWidget {
  const _DefaultEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
