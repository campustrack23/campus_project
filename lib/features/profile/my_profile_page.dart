// lib/features/profile/my_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../core/utils/firebase_error_parser.dart';
import '../../main.dart';
import '../common/widgets/async_error_widget.dart';

// -----------------------------------------------------------------------------
// ROLE-SPECIFIC PROVIDERS
// -----------------------------------------------------------------------------

final studentProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');

  final records = await ref.watch(attendanceRepoProvider).forStudent(user.id);
  final total = records.length;

  final present = records.where((r) =>
  r.status == AttendanceStatus.present ||
      r.status == AttendanceStatus.excused ||
      r.status == AttendanceStatus.late).length;

  final pct = total == 0 ? 100 : ((present * 100) / total).round();

  return (total: total, present: present, pct: pct);
});

final teacherProfileSubjectsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');

  final subjects = await ref.watch(timetableRepoProvider).allSubjects();
  final mySubjects = subjects.where((s) => s.teacherId == user.id).toList();
  final sections = mySubjects.map((s) => s.section).toSet().toList()..sort();

  return (subjects: mySubjects, sections: sections);
});

final adminProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final db = FirebaseFirestore.instance;

  // PERFORMANCE FIX: Use Server-Side Aggregation (count) instead of downloading entire collections
  final results = await Future.wait([
    db.collection('users').count().get(),
    db.collection('subjects').count().get(),
    db.collection('attendance').count().get(),
  ]);

  return (
  users: results[0].count ?? 0,
  subjects: results[1].count ?? 0,
  records: results[2].count ?? 0,
  );
});

// -----------------------------------------------------------------------------
// MAIN PAGE
// -----------------------------------------------------------------------------

class MyProfilePage extends ConsumerWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(authStateProvider),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return switch (user.role) {
            UserRole.student => _StudentProfileView(user: user),
            UserRole.teacher => _TeacherProfileView(user: user),
            UserRole.admin => _AdminProfileView(user: user),
          };
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STUDENT PROFILE
// -----------------------------------------------------------------------------

class _StudentProfileView extends ConsumerWidget {
  final UserAccount user;
  const _StudentProfileView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(studentProfileStatsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 24),
          _AttendanceSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'Academic Details',
            children: [
              _InfoTile(
                icon: Icons.badge,
                title: 'College Roll',
                value: user.collegeRollNo ?? '—',
              ),
              _InfoTile(
                icon: Icons.confirmation_number,
                title: 'Exam Roll',
                value: user.examRollNo ?? '—',
              ),
              if (user.section?.isNotEmpty ?? false)
                _InfoTile(
                  icon: Icons.class_,
                  title: 'Section',
                  value: user.section!,
                ),
              _InfoTile(
                icon: Icons.phone,
                title: 'Phone',
                value: user.phone,
              ),
              _InfoTile(
                icon: Icons.email,
                title: 'Email',
                value: user.email ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// TEACHER PROFILE
// -----------------------------------------------------------------------------

class _TeacherProfileView extends ConsumerWidget {
  final UserAccount user;
  const _TeacherProfileView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teacherProfileSubjectsProvider);
        ref.invalidate(authStateProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 24),
          _QualificationsCard(user: user),
          const SizedBox(height: 16),
          _SubjectsSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'Contact',
            children: [
              _InfoTile(
                icon: Icons.phone,
                title: 'Phone',
                value: user.phone,
              ),
              _InfoTile(
                icon: Icons.email,
                title: 'Email',
                value: user.email ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADMIN PROFILE
// -----------------------------------------------------------------------------

class _AdminProfileView extends ConsumerWidget {
  final UserAccount user;
  const _AdminProfileView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminProfileStatsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 24),
          _AppSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'Contact',
            children: [
              _InfoTile(
                icon: Icons.phone,
                title: 'Phone',
                value: user.phone,
              ),
              _InfoTile(
                icon: Icons.email,
                title: 'Email',
                value: user.email ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROFILE HEADER (COMMON)
// -----------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  final UserAccount user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: color,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(user.role.label.toUpperCase()),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          side: BorderSide.none,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ATTENDANCE SUMMARY (STUDENT)
// -----------------------------------------------------------------------------

class _AttendanceSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(studentProfileStatsProvider);

    return _SettingsGroupCard(
      title: 'Attendance Overview',
      children: [
        asyncStats.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(studentProfileStatsProvider),
          ),
          data: (stats) {
            final Color pctColor = stats.pct < 75
                ? Colors.red
                : (stats.pct < 85 ? Colors.orange : Colors.green);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${stats.pct}%',
                    label: 'Overall',
                    color: pctColor,
                    large: true,
                  ),
                  _StatItem(
                    value: stats.present.toString(),
                    label: 'Attended',
                  ),
                  _StatItem(
                    value: stats.total.toString(),
                    label: 'Total',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
// -----------------------------------------------------------------------------
// TEACHER SUBJECT SUMMARY
// -----------------------------------------------------------------------------

class _SubjectsSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(teacherProfileSubjectsProvider);

    return _SettingsGroupCard(
      title: 'Teaching Assignments',
      children: [
        asyncData.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(teacherProfileSubjectsProvider),
          ),
          data: (data) {
            if (data.subjects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No subjects assigned yet.'),
              );
            }

            return Column(
              children: [
                if (data.sections.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      children: data.sections
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                ...data.subjects.map(
                      (s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.book_outlined),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(s.code),
                    trailing: Text('Sec: ${s.section}'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ADMIN APP SUMMARY
// -----------------------------------------------------------------------------

class _AppSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminProfileStatsProvider);

    return _SettingsGroupCard(
      title: 'System Overview',
      children: [
        asyncData.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(adminProfileStatsProvider),
          ),
          data: (data) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: data.users.toString(), label: 'Users'),
                _StatItem(
                    value: data.subjects.toString(), label: 'Subjects'),
                _StatItem(
                    value: data.records.toString(), label: 'Records'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// QUALIFICATIONS (TEACHER)
// -----------------------------------------------------------------------------

class _QualificationsCard extends ConsumerWidget {
  final UserAccount user;
  const _QualificationsCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsGroupCard(
      title: 'Qualifications',
      children: [
        if (user.qualifications.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No qualifications added yet.'),
          )
        else
          ...user.qualifications.map(
                (q) => ListTile(
              dense: true,
              leading: const Icon(Icons.school),
              title: Text(q),
            ),
          ),
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Manage'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _EditQualificationsDialog(user: user),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// EDIT QUALIFICATIONS DIALOG  ✅ FIXES YOUR ERROR
// -----------------------------------------------------------------------------

class _EditQualificationsDialog extends ConsumerStatefulWidget {
  final UserAccount user;
  const _EditQualificationsDialog({required this.user});

  @override
  ConsumerState<_EditQualificationsDialog> createState() =>
      _EditQualificationsDialogState();
}

class _EditQualificationsDialogState
    extends ConsumerState<_EditQualificationsDialog> {
  late List<String> _quals;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quals = List.from(widget.user.qualifications);
  }

  void _add() {
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _quals.add(text);
        _ctrl.clear();
      });
    }
  }

  void _remove(int index) {
    setState(() => _quals.removeAt(index));
  }

  Future<void> _save() async {
    try {
      await ref.read(authRepoProvider).updateUser(
        widget.user.copyWith(qualifications: _quals),
      );
      ref.invalidate(authStateProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Qualifications'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_quals.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _quals.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    title: Text(_quals[i]),
                    trailing: IconButton(
                      icon:
                      const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _remove(i),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Add qualification',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _add(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
// -----------------------------------------------------------------------------
// SETTINGS + ACCOUNT ACTIONS
// -----------------------------------------------------------------------------

class _CommonSettingsSection extends ConsumerWidget {
  final UserAccount user;
  const _CommonSettingsSection({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsGroupCard(
      title: 'Account Settings',
      children: [
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showChangePasswordDialog(
            context,
            ref,
            user.email!,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            await ref.read(authRepoProvider).logout();
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => _confirmDelete(context, ref, user),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CHANGE PASSWORD
  // ---------------------------------------------------------------------------

  Future<void> _showChangePasswordDialog(
      BuildContext context,
      WidgetRef ref,
      String email,
      ) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Text('Send password reset link to:\n\n$email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(authRepoProvider)
                    .requestPasswordReset(email);

                if (!context.mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset link sent'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                final msg = FirebaseErrorParser.getMessage(e);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE ACCOUNT
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(
      BuildContext context,
      WidgetRef ref,
      UserAccount user,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authRepoProvider).deleteAccount(user.id);
        await ref.read(authRepoProvider).logout();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// -----------------------------------------------------------------------------
// SHARED UI WIDGETS
// -----------------------------------------------------------------------------

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroupCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final bool large;
  const _StatItem({
    required this.value,
    required this.label,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 32 : 22,
            fontWeight: FontWeight.bold,
            color:
            color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }
}