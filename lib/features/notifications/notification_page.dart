// lib/features/notifications/notification_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/models/notification.dart';
import '../../main.dart';
// import '../../data/notification_repository.dart'; // Not strictly needed if using main.dart provider, but kept for type safety if needed

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              authState.whenData((user) {
                if (user != null) _confirmClear(context, ref, user.id);
              });
            },
          ),
          const ProfileAvatarAction(),
        ],
      ),
      drawer: const AppDrawer(),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('Please login'));

          return StreamBuilder<List<AppNotification>>(
            // Now this uses the provider from main.dart without conflict
            stream: ref.watch(notifRepoProvider).listenForUser(user.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading notifications: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: Key(item.id),
                    background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white)),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      // Optionally implement delete single item
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.read ? Colors.grey[300] : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(_getIconForType(item.type),
                            color: item.read ? Colors.grey : Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(fontWeight: item.read ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.body),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(item.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!item.read) {
                          ref.read(notifRepoProvider).markRead(item.id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(notifRepoProvider).clearForUser(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications cleared')));
      }
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.classChange:
        return Icons.schedule;
      case NotificationType.lowAttendance:
        return Icons.warning_amber_rounded;
      case NotificationType.queryUpdate:
        return Icons.question_answer_outlined;
      case NotificationType.remarkSaved:
        return Icons.rate_review_outlined;
      case NotificationType.general:
      return Icons.notifications;
    }
  }
}