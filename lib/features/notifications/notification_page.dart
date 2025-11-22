// lib/features/notifications/notification_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/models/notification.dart';
import '../../main.dart';
import '../../data/notification_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please login')));
        }

        final repo = ref.watch(notifRepoProvider);
        final items = repo.forUser(user.id);
        final hasUnread = items.any((n) => !n.read);
        final fmt = DateFormat('MMM d, h:mm a');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Clear All',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClearAll(context, repo, user.id),
                ),
              IconButton(
                icon: Icon(
                  hasUnread
                      ? Icons.mark_email_read
                      : Icons.mark_email_read_outlined,
                  color: hasUnread
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Mark all read',
                onPressed: hasUnread
                    ? () async {
                  final messenger = ScaffoldMessenger.of(context);

                  await repo.markAllRead(user.id);

                  if (!mounted) return;

                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Marked all as read')),
                  );

                  setState(() {});
                }
                    : null,
              ),
              const SizedBox(width: 8),
              const ProfileAvatarAction(),
              const SizedBox(width: 12),
            ],
          ),
          drawer: const AppDrawer(),
          body: items.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4)), // FIXED
                const SizedBox(height: 16),
                Text('No notifications',
                    style:
                    TextStyle(color: Colors.grey.withValues(alpha: 0.6))),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = items[i];
                return Dismissible(
                  key: Key(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await repo.delete(n.id);
                    if (mounted) setState(() {});
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    tileColor: n.read
                        ? null
                        : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.05), // FIXED
                    leading: CircleAvatar(
                      backgroundColor: n.read
                          ? Colors.grey.withValues(alpha: 0.15)
                          : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15), // FIXED
                      child: Icon(
                        _getIconForType(n.type),
                        color: n.read
                            ? Colors.grey
                            : Theme.of(context)
                            .colorScheme
                            .primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.read
                            ? FontWeight.normal
                            : FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n.body,
                            style: const TextStyle(height: 1.3)),
                        const SizedBox(height: 6),
                        Text(
                          fmt.format(n.createdAt.toLocal()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (!n.read) {
                        await repo.markRead(n.id);
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context, NotificationRepository repo, String userId) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text(
            'Delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repo.clearForUser(userId);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );

      setState(() {});
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
        return Icons.notifications; // DEFAULT REMOVED
    }
  }
}
