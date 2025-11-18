// lib/features/common/widgets/logout_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';

class LogoutButton extends ConsumerWidget {
  final bool confirm;
  const LogoutButton({super.key, this.confirm = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        bool proceed = true;
        if (confirm) {
          proceed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
              ],
            ),
          ) ??
              false;
        }
        if (!proceed) return;

        // Stop Firestore notification sync
        ref.read(notifSyncProvider).stop();

        await ref.read(authRepoProvider).logout();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
        context.go('/login');
      },
    );
  }
}