// lib/features/admin/query_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/query_ticket.dart';
import '../../core/models/user.dart';
import '../../main.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/async_error_widget.dart';

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------

final queryManagementProvider = FutureProvider.autoDispose((ref) async {
  final queryRepo = ref.watch(queryRepoProvider);
  final authRepo = ref.watch(authRepoProvider);

  final queries = await queryRepo.allQueries();
  final users = await authRepo.allUsers();

  return {
    'queries': queries,
    'users': users,
  };
});

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------

class QueryManagementPage extends ConsumerWidget {
  const QueryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(queryManagementProvider);

    return asyncData.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Manage Queries')),
        body: AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(queryManagementProvider),
        ),
      ),
      data: (data) {
        final queries = data['queries'] as List<QueryTicket>;
        final usersList = data['users'] as List<UserAccount>;
        final users = {for (final u in usersList) u.id: u};

        final open = queries.where((q) => q.status == QueryStatus.open).toList();
        final inProgress =
        queries.where((q) => q.status == QueryStatus.inProgress).toList();
        final resolved =
        queries.where((q) => q.status == QueryStatus.resolved).toList();
        final rejected =
        queries.where((q) => q.status == QueryStatus.rejected).toList();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: const Text('Manage Queries'),
              actions: [
                const ProfileAvatarAction(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.invalidate(queryManagementProvider),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Open (${open.length})'),
                  Tab(text: 'In Progress (${inProgress.length})'),
                  Tab(text: 'Resolved (${resolved.length})'),
                  Tab(text: 'Rejected (${rejected.length})'),
                ],
              ),
            ),
            drawer: const AppDrawer(),
            body: TabBarView(
              children: [
                _QueryList(queries: open, users: users),
                _QueryList(queries: inProgress, users: users),
                _QueryList(queries: resolved, users: users),
                _QueryList(queries: rejected, users: users),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// QUERY LIST
// -----------------------------------------------------------------------------

class _QueryList extends ConsumerWidget {
  final List<QueryTicket> queries;
  final Map<String, UserAccount> users;

  const _QueryList({
    required this.queries,
    required this.users,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (queries.isEmpty) {
      return const Center(child: Text('No queries in this category.'));
    }

    final fmt = DateFormat('MMM d, h:mm a');

    return ListView.separated(
      itemCount: queries.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final query = queries[i];
        final student = users[query.raisedByStudentId];

        return ListTile(
          leading: Icon(_statusIcon(query.status),
              color: _statusColor(query.status)),
          title: Text(query.title),
          subtitle: Text(
            'From: ${student?.name ?? 'Unknown'}\n'
                '${fmt.format(query.createdAt.toLocal())}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showQueryDialog(
            context,
            ref,
            query,
            student,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // QUERY DETAILS DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _showQueryDialog(
      BuildContext context,
      WidgetRef ref,
      QueryTicket query,
      UserAccount? student,
      ) async {
    QueryStatus newStatus = query.status;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(query.title),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(query.message, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  if (student != null) ...[
                    const Divider(),
                    Text('Student Details',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('Name: ${student.name}'),
                    Text('Phone: ${student.phone}'),
                    if (student.collegeRollNo != null)
                      Text('Roll: ${student.collegeRollNo}'),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QueryStatus>(
                    value: newStatus,
                    decoration:
                    const InputDecoration(labelText: 'Update Status'),
                    items: QueryStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name),
                      ),
                    )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => newStatus = v ?? query.status),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () async {
                  if (newStatus != query.status) {
                    await ref
                        .read(queryRepoProvider)
                        .updateStatus(query.id, newStatus);
                    ref.invalidate(queryManagementProvider);
                  }
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                        Text('Query status updated successfully'),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static Color _statusColor(QueryStatus s) {
    switch (s) {
      case QueryStatus.open:
        return Colors.grey;
      case QueryStatus.inProgress:
        return Colors.blue;
      case QueryStatus.resolved:
        return Colors.green;
      case QueryStatus.rejected:
        return Colors.red;
    }
  }

  static IconData _statusIcon(QueryStatus s) {
    switch (s) {
      case QueryStatus.open:
        return Icons.mark_email_unread;
      case QueryStatus.inProgress:
        return Icons.pending;
      case QueryStatus.resolved:
        return Icons.check_circle;
      case QueryStatus.rejected:
        return Icons.cancel;
    }
  }
}
