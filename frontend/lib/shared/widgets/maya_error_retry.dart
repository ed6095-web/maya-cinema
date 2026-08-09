// MAYA — Shared Error Retry Widget
// Drop this anywhere a FutureProvider fails — shows a centered
// error message with a retry button that re-fires the provider.

import 'package:flutter/material.dart';
import 'package:maya_app/app/theme.dart';

class MayaErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String? customMessage;

  const MayaErrorRetry({
    super.key,
    required this.error,
    required this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final msg = customMessage ?? _friendlyMessage(error.toString());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MayaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: MayaColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: MayaColors.error, size: 28),
            ),
            const SizedBox(height: MayaSpacing.md),
            Text(
              'Something went wrong',
              style: MayaTextStyles.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MayaSpacing.sm),
            Text(
              msg,
              style: MayaTextStyles.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MayaSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    // Strip "Exception: " prefix that comes from DioException wrapping
    final cleaned = raw.replaceFirst('Exception: ', '');
    if (cleaned.contains('SocketException') || cleaned.contains('Connection refused')) {
      return 'Cannot reach the server. Make sure the backend is running.';
    }
    if (cleaned.contains('401') || cleaned.contains('Unauthorized') || cleaned.contains('Not authenticated')) {
      return 'Your session has expired or you are not signed in. Please sign in again.';
    }
    if (cleaned.contains('403') || cleaned.contains('Forbidden')) {
      return 'You do not have permission to view this content.';
    }
    if (cleaned.contains('404') || cleaned.contains('Not found')) {
      return 'This content could not be found.';
    }
    if (cleaned.contains('500') || cleaned.contains('Internal')) {
      return 'The server encountered an error. Please try again later.';
    }
    if (cleaned.contains('timeout') || cleaned.contains('Timeout')) {
      return 'The request timed out. Check your network connection.';
    }
    return cleaned.length > 120 ? '${cleaned.substring(0, 120)}…' : cleaned;
  }
}

/// Inline compact error — use inside a list or card
class MayaInlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const MayaInlineError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MayaSpacing.md,
        vertical: MayaSpacing.sm,
      ),
      margin: const EdgeInsets.symmetric(vertical: MayaSpacing.sm),
      decoration: BoxDecoration(
        color: MayaColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(color: MayaColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: MayaColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: MayaTextStyles.labelSmall.copyWith(color: MayaColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
