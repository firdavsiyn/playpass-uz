import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/error_text.dart';

/// Friendly full-screen error state with an optional retry button.
/// Use in `AsyncValue.when(error: ...)` instead of dumping `Text('$e')`.
///
/// Example:
///   error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(p)),
class ErrorRetry extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  /// Override the auto-derived message if a screen wants something specific.
  final String? message;

  const ErrorRetry({super.key, this.error, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    final msg = message ?? friendlyError(error);
    final isNetwork = msg.startsWith('Нет связи');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                color: AppTheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.text2,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Повторить'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
