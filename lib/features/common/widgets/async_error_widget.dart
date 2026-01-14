// lib/features/common/widgets/async_error_widget.dart
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
    return Center(
      // Prevent overflow with scrollable container
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded, // Descriptive icon for connectivity errors
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _cleanMessage(message),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            // Copy error details button for debugging help
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _cleanMessage(message)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error copied to clipboard')),
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

  // Makes error messages more human-readable and user-helpful
  String _cleanMessage(String raw) {
    if (raw.contains('SocketException') || raw.contains('Network is unreachable')) {
      return 'Please check your internet connection.';
    }
    return raw.replaceAll('Exception: ', '').trim();
  }
}
