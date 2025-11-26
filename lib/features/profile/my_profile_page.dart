// lib/features/profile/my_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../main.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/utils/firebase_error_parser.dart';

// --- ROLE-SPECIFIC PROVIDERS ---

final studentProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');

  final records = await ref.watch(attendanceRepoProvider).forStudent(user.id);
  final total = records.length;

  // FIX: Late counts as present
  final present = records.where((r) =>
  r.status == AttendanceStatus.present ||
      r.status == AttendanceStatus.excused ||
      r.status == AttendanceStatus.late
  ).length;

  final pct = total == 0 ? 100 : ((present * 100) / total).round();

  return (total: total, present: present, pct: pct);
});

final teacherProfileSubjectsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');

  final allSubjects = await ref.watch(timetableRepoProvider).allSubjects();
  final mySubjects = allSubjects.where((s) => s.teacherId == user.id).toList();
  final mySections = mySubjects.map((s) => s.section).toSet().toList()..sort();

  return (subjects: mySubjects, sections: mySections);
});

final adminProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    ref.watch(authRepoProvider).allUsers(),
    ref.watch(timetableRepoProvider).allSubjects(),
    ref.watch(attendanceRepoProvider).allRecords(),
  ]);

  final userCount = (results[0] as List).length;
  final subjectCount = (results[1] as List).length;
  final recordCount = (results[2] as List).length;

  return (users: userCount, subjects: subjectCount, records: recordCount);
});

// --- MAIN PROFILE PAGE WIDGET ---

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
        error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(authStateProvider)
        ),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

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
              _InfoTile(icon: Icons.badge_outlined, title: 'College Roll No', value: user.collegeRollNo ?? '—'),
              _InfoTile(icon: Icons.confirmation_number_outlined, title: 'Exam Roll No', value: user.examRollNo ?? '—'),
              if (user.section?.isNotEmpty ?? false)
                _InfoTile(icon: Icons.class_outlined, title: 'Section', value: user.section!),
              _InfoTile(icon: Icons.phone_outlined, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.email_outlined, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TeacherProfileView extends ConsumerWidget {
  final UserAccount user;
  const _TeacherProfileView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshData() async {
      ref.invalidate(teacherProfileSubjectsProvider);
      ref.invalidate(authStateProvider);
    }

    return RefreshIndicator(
      onRefresh: refreshData,
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
            title: 'Contact Details',
            children: [
              _InfoTile(icon: Icons.phone_outlined, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.email_outlined, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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
            title: 'My Details',
            children: [
              _InfoTile(icon: Icons.phone_outlined, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.email_outlined, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// --- CARDS & WIDGETS ---

class _AttendanceSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentProfileStatsProvider);

    return _SettingsGroupCard(
      title: 'Attendance Overview',
      children: [
        statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(studentProfileStatsProvider),
          ),
          data: (stats) {
            final Color pctColor = stats.pct < 75
                ? Colors.red
                : (stats.pct < 85 ? Colors.orange : Colors.green);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
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

class _SubjectsSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(teacherProfileSubjectsProvider);

    return _SettingsGroupCard(
      title: 'Teaching Assignments',
      children: [
        asyncData.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(teacherProfileSubjectsProvider),
          ),
          data: (data) {
            if (data.subjects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subjects assigned yet.'),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.sections.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('My Sections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8,
                      children: data.sections.map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  ),
                  const Divider(),
                ],
                ...data.subjects.map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.book_outlined),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s.code),
                  trailing: Text('Sec: ${s.section}'),
                )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AppSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminProfileStatsProvider);

    return _SettingsGroupCard(
      title: 'System Overview',
      children: [
        asyncData.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (err, _) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(adminProfileStatsProvider),
          ),
          data: (data) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(value: data.users.toString(), label: 'Users'),
                  _StatItem(value: data.subjects.toString(), label: 'Subjects'),
                  _StatItem(value: data.records.toString(), label: 'Records'),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

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
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No qualifications added yet.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...user.qualifications.map(
                (q) => ListTile(
              dense: true,
              leading: const Icon(Icons.school, size: 20),
              title: Text(q),
            ),
          ),
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Manage'),
            onPressed: () => _showEditQualificationsDialog(context, ref, user),
          ),
        )
      ],
    );
  }

  Future<void> _showEditQualificationsDialog(BuildContext context, WidgetRef ref, UserAccount user) async {
    await showDialog(
      context: context,
      builder: (context) => _EditQualificationsDialog(user: user),
    );
  }
}

class _EditQualificationsDialog extends ConsumerStatefulWidget {
  final UserAccount user;
  const _EditQualificationsDialog({required this.user});

  @override
  ConsumerState<_EditQualificationsDialog> createState() => _EditQualificationsDialogState();
}

class _EditQualificationsDialogState extends ConsumerState<_EditQualificationsDialog> {
  late List<String> _qualifications;
  final TextEditingController _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qualifications = List.from(widget.user.qualifications);
  }

  void _add() {
    final text = _addCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _qualifications.add(text);
        _addCtrl.clear();
      });
    }
  }

  void _remove(int index) {
    setState(() {
      _qualifications.removeAt(index);
    });
  }

  Future<void> _save() async {
    final auth = ref.read(authRepoProvider);
    try {
      await auth.updateUser(
        widget.user.copyWith(qualifications: _qualifications),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_qualifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Add your degrees (e.g. PhD, M.Tech)', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              ),

            if (_qualifications.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _qualifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(_qualifications[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => _remove(index),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            TextField(
              controller: _addCtrl,
              decoration: InputDecoration(
                labelText: 'Add Qualification',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: _add,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _add(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserAccount user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: roleColor,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(user.role.label.toUpperCase()),
          labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          side: BorderSide.none,
        ),
      ],
    );
  }
}

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
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () => _showChangePasswordDialog(context, ref, user.email!),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          onTap: () async {
            await ref.read(authRepoProvider).logout();
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
          title: Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          subtitle: const Text('Permanently delete your data', style: TextStyle(fontSize: 11)),
          onTap: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, WidgetRef ref, String email) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Text('We will send a password reset link to:\n\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(authRepoProvider).requestPasswordReset(email);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset link sent to your email.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                final message = FirebaseErrorParser.getMessage(e);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This will permanently delete your profile and cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authRepoProvider).deleteAccount();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroupCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.primary
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
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: Colors.grey[600]),
      title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      trailing: Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface
          )
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final bool large;
  const _StatItem({required this.value, required this.label, this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 32 : 24,
            fontWeight: FontWeight.w900,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500
          ),
        ),
      ],
    );
  }
}