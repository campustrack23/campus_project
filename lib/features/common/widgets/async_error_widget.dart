import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AsyncErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AsyncErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _cleanMessage(message),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _cleanMessage(message)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error details copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy details'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR MESSAGE CLEANUP
  // ---------------------------------------------------------------------------

  String _cleanMessage(String raw) {
    final lower = raw.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup')) {
      return 'Please check your internet connection and try again.';
    }

    if (lower.contains('permission')) {
      return 'You do not have permission to perform this action.';
    }

    return raw.replaceAll('Exception:', '').trim();
  }
}
