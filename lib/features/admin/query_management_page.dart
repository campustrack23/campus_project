// lib/features/admin/query_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/query_ticket.dart';
import '../../core/models/user.dart';
import '../../core/models/subject.dart';
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
  final ttRepo = ref.watch(timetableRepoProvider);

  final queries = await queryRepo.allQueries();
  final users = await authRepo.allUsers();
  final subjects = await ttRepo.allSubjects();

  return {
    'queries': queries..sort((a, b) => b.createdAt.compareTo(a.createdAt)), // Newest first
    'users': users,
    'subjects': subjects,
  };
});

// -----------------------------------------------------------------------------
// PAGE W/ FILTERS
// -----------------------------------------------------------------------------

class QueryManagementPage extends ConsumerStatefulWidget {
  const QueryManagementPage({super.key});

  @override
  ConsumerState<QueryManagementPage> createState() => _QueryManagementPageState();
}

class _QueryManagementPageState extends ConsumerState<QueryManagementPage> {
  String _searchQuery = '';
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(queryManagementProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Manage Queries'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(queryManagementProvider),
          ),
          const ProfileAvatarAction(),
        ],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(queryManagementProvider),
        ),
        data: (data) {
          final allQueries = data['queries'] as List<QueryTicket>;
          final usersList = data['users'] as List<UserAccount>;
          final subjectsList = data['subjects'] as List<Subject>;

          final usersMap = {for (final u in usersList) u.id: u};
          final subjectsMap = {for (final s in subjectsList) s.id: s};

          // 1. Apply Search and Subject Filters First
          final filteredQueries = allQueries.where((q) {
            // Filter by Subject
            if (_selectedSubjectId != null && _selectedSubjectId != 'GENERAL') {
              if (q.subjectId != _selectedSubjectId) return false;
            } else if (_selectedSubjectId == 'GENERAL') {
              if (q.subjectId != null) return false; // Exclude specific subjects
            }

            // Filter by Search Text (Title, Message, Student Name, Roll No)
            if (_searchQuery.isNotEmpty) {
              final queryText = _searchQuery.toLowerCase();
              final student = usersMap[q.raisedByStudentId];

              final matchTitle = q.title.toLowerCase().contains(queryText);
              final matchMsg = q.message.toLowerCase().contains(queryText);
              final matchName = student?.name.toLowerCase().contains(queryText) ?? false;
              final matchRoll = student?.collegeRollNo?.toLowerCase().contains(queryText) ?? false;

              if (!matchTitle && !matchMsg && !matchName && !matchRoll) {
                return false;
              }
            }

            return true;
          }).toList();

          // 2. Split filtered results into Tabs
          final open = filteredQueries.where((q) => q.status == QueryStatus.open).toList();
          final inProgress = filteredQueries.where((q) => q.status == QueryStatus.inProgress).toList();
          final resolved = filteredQueries.where((q) => q.status == QueryStatus.resolved).toList();
          final rejected = filteredQueries.where((q) => q.status == QueryStatus.rejected).toList();

          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // --- MODERN FILTER BAR ---
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search queries or students...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedSubjectId,
                                  isExpanded: true,
                                  icon: const Icon(Icons.filter_list, size: 20),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Subjects')),
                                    const DropdownMenuItem(value: 'GENERAL', child: Text('General Queries')),
                                    ...subjectsList.map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    )),
                                  ],
                                  onChanged: (v) => setState(() => _selectedSubjectId = v),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: [
                          Tab(text: 'Open (${open.length})'),
                          Tab(text: 'In Progress (${inProgress.length})'),
                          Tab(text: 'Resolved (${resolved.length})'),
                          Tab(text: 'Rejected (${rejected.length})'),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- TAB VIEWS ---
                Expanded(
                  child: TabBarView(
                    children: [
                      _QueryList(queries: open, users: usersMap, subjects: subjectsMap),
                      _QueryList(queries: inProgress, users: usersMap, subjects: subjectsMap),
                      _QueryList(queries: resolved, users: usersMap, subjects: subjectsMap),
                      _QueryList(queries: rejected, users: usersMap, subjects: subjectsMap),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// QUERY LIST
// -----------------------------------------------------------------------------

class _QueryList extends ConsumerWidget {
  final List<QueryTicket> queries;
  final Map<String, UserAccount> users;
  final Map<String, Subject> subjects;

  const _QueryList({
    required this.queries,
    required this.users,
    required this.subjects,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (queries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No queries found.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final fmt = DateFormat('MMM d, h:mm a');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queries.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final query = queries[i];
        final student = users[query.raisedByStudentId];
        final subjectName = query.subjectId != null ? subjects[query.subjectId]?.name : 'General';

        return InkWell(
          onTap: () => _showQueryDialog(context, ref, query, student, subjectName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor(query.status).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _statusIcon(query.status),
                    color: _statusColor(query.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              query.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(query.createdAt.toLocal()),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        query.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            student?.name ?? 'Unknown Student',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          if (student?.collegeRollNo != null) ...[
                            Text(
                              ' (${student!.collegeRollNo})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subjectName ?? 'General',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MODERN QUERY DETAILS DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _showQueryDialog(
      BuildContext context,
      WidgetRef ref,
      QueryTicket query,
      UserAccount? student,
      String? subjectName,
      ) async {
    QueryStatus newStatus = query.status;
    final fmt = DateFormat('EEEE, MMM d, yyyy • h:mm a');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _statusColor(newStatus).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_statusIcon(newStatus), color: _statusColor(newStatus)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(query.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(fmt.format(query.createdAt.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Message Body
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      query.message,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metadata Grid
                  Row(
                    children: [
                      Expanded(
                        child: _DetailTile(label: 'Student', value: student?.name ?? 'Unknown'),
                      ),
                      Expanded(
                        child: _DetailTile(label: 'Roll No', value: student?.collegeRollNo ?? 'N/A'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailTile(label: 'Phone', value: student?.phone ?? 'N/A'),
                      ),
                      Expanded(
                        child: _DetailTile(label: 'Subject Context', value: subjectName ?? 'General'),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),

                  // Action Area
                  const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<QueryStatus>(
                    initialValue: newStatus,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: QueryStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(_statusIcon(s), color: _statusColor(s), size: 18),
                          const SizedBox(width: 12),
                          Text(s.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => newStatus = v ?? query.status),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (newStatus != query.status) {
                            await ref.read(queryRepoProvider).updateStatus(query.id, newStatus);
                            ref.invalidate(queryManagementProvider);
                          }
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Query status updated successfully')),
                            );
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      case QueryStatus.open: return Colors.orange;
      case QueryStatus.inProgress: return Colors.blue;
      case QueryStatus.resolved: return Colors.green;
      case QueryStatus.rejected: return Colors.red;
    }
  }

  static IconData _statusIcon(QueryStatus s) {
    switch (s) {
      case QueryStatus.open: return Icons.mark_email_unread_rounded;
      case QueryStatus.inProgress: return Icons.pending_actions_rounded;
      case QueryStatus.resolved: return Icons.check_circle_rounded;
      case QueryStatus.rejected: return Icons.cancel_rounded;
    }
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}