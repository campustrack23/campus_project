import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/models/user.dart';
import '../../main.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, h:mm a');

    return FutureBuilder<UserAccount?>(
      future: ref.read(authRepoProvider).currentUser(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final me = snap.data!;
        final repo = ref.read(notifRepoProvider);
        final items = repo.forUser(me.id);
        final hasUnread = repo.unreadForUser(me.id).isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Notifications'),
            actions: [
              const ProfileAvatarAction(),
              IconButton(
                icon: const Icon(Icons.mark_email_read_outlined),
                tooltip: 'Mark all read',
                onPressed: hasUnread
                    ? () async {
                  await repo.markAllRead(me.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked all as read')),
                  );
                  setState(() {});
                }
                    : null,
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: items.isEmpty
              ? const Center(child: Text('No notifications'))
              : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final n = items[i];
                return ListTile(
                  leading: Icon(
                    n.read ? Icons.notifications_none : Icons.notifications_active,
                    color: n.read ? Colors.grey : Colors.blueAccent,
                  ),
                  title: Text(n.title),
                  subtitle: Text(n.body),
                  trailing: Text(
                    fmt.format(n.createdAt.toLocal()),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    if (!n.read) {
                      await repo.markRead(n.id);
                      if (mounted) setState(() {});
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}