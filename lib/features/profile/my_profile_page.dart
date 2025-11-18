// lib/features/profile/my_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../core/models/subject.dart';
import '../../main.dart';
import '../common/widgets/async_error_widget.dart';
// --- FIX: Import the new error parser ---
import '../../core/utils/firebase_error_parser.dart';

// --- ROLE-SPECIFIC PROVIDERS ---
final studentProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');
  final records = await ref.watch(attendanceRepoProvider).forStudent(user.id);
  final total = records.length;
  final present = records
      .where((r) =>
  r.status == AttendanceStatus.present ||
      r.status == AttendanceStatus.excused)
      .length;
  final pct = total == 0 ? 100 : ((present * 100) / total).round();
  return (total: total, present: present, pct: pct);
});

final teacherProfileSubjectsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');
  final allSubjects = await ref.watch(timetableRepoProvider).allSubjects();
  final mySubjects = allSubjects
      .where((s) => s.teacherId == user.id)
      .toList();
  final mySections = mySubjects.map((s) => s.section).toSet().toList()..sort();
  return (subjects: mySubjects, sections: mySections);
});

final adminProfileStatsProvider = FutureProvider.autoDispose((ref) async {
  final userCount = (await ref.watch(authRepoProvider).allUsers()).length;
  final subjectCount = (await ref.watch(timetableRepoProvider).allSubjects()).length;
  final recordCount = (await ref.watch(attendanceRepoProvider).allRecords()).length;
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
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
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

// --- STUDENT PROFILE VIEW ---
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
          const SizedBox(height: 16),
          _AttendanceSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'My Details',
            children: [
              _InfoTile(icon: Icons.badge, title: 'College Roll No.', value: user.collegeRollNo ?? '—'),
              _InfoTile(icon: Icons.confirmation_number, title: 'Exam Roll No.', value: user.examRollNo ?? '—'),
              if (user.section?.isNotEmpty ?? false)
                _InfoTile(icon: Icons.school, title: 'Section', value: user.section!),
              _InfoTile(icon: Icons.phone, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.alternate_email, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}

// --- TEACHER PROFILE VIEW ---
class _TeacherProfileView extends ConsumerWidget {
  final UserAccount user;
  const _TeacherProfileView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refreshData() async {
      await Future.wait([
        ref.refresh(teacherProfileSubjectsProvider.future),
        ref.refresh(authStateProvider.future),
      ]);
    }

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 16),
          _QualificationsCard(user: user),
          const SizedBox(height: 16),
          _SubjectsSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'My Details',
            children: [
              _InfoTile(icon: Icons.phone, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.alternate_email, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}

// --- ADMIN PROFILE VIEW ---
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
          const SizedBox(height: 16),
          _AppSummaryCard(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            title: 'My Details',
            children: [
              _InfoTile(icon: Icons.phone, title: 'Phone', value: user.phone),
              _InfoTile(icon: Icons.alternate_email, title: 'Email', value: user.email ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _CommonSettingsSection(user: user),
        ],
      ),
    );
  }
}

// --- ROLE-SPECIFIC WIDGETS ---
class _AttendanceSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentProfileStatsProvider);
    return _SettingsGroupCard(
      title: 'Attendance Summary',
      children: [
        statsAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: AsyncErrorWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(studentProfileStatsProvider),
            ),
          ),
          data: (stats) {
            final Color pctColor = stats.pct < 75 ? Colors.red : (stats.pct < 85 ? Colors.orange : Colors.green);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  value: '${stats.pct}%',
                  label: 'Overall',
                  color: pctColor,
                ),
                _StatItem(
                  value: stats.present.toString(),
                  label: 'Attended',
                ),
                _StatItem(
                  value: stats.total.toString(),
                  label: 'Total Classes',
                ),
              ],
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
      title: 'My Assignments',
      children: [
        asyncData.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: AsyncErrorWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(teacherProfileSubjectsProvider),
            ),
          ),
          data: (data) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  title: Text('Sections', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8,
                    children: data.sections.map((s) => Chip(label: Text(s))).toList(),
                  ),
                ),
                const ListTile(
                  title: Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...data.subjects.map((s) => ListTile(
                  dense: true,
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(s.code),
                  trailing: Text(s.section),
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
      title: 'App Statistics',
      children: [
        asyncData.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: AsyncErrorWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(adminProfileStatsProvider),
            ),
          ),
          data: (data) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: data.users.toString(), label: 'Total Users'),
                _StatItem(value: data.subjects.toString(), label: 'Subjects'),
                _StatItem(value: data.records.toString(), label: 'Records'),
              ],
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
      title: 'My Qualifications',
      children: [
        if (user.qualifications.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No qualifications added yet.'),
            ),
          )
        else
          ...user.qualifications.map(
                (q) => ListTile(
              dense: true,
              leading: const Icon(Icons.school_outlined, size: 22),
              title: Text(q),
            ),
          ),
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
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
      title: const Text('Edit Qualifications'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_qualifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No qualifications yet. Add one below.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _qualifications.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_qualifications[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _remove(index),
                      ),
                    );
                  },
                ),
              const Divider(),
              TextField(
                controller: _addCtrl,
                decoration: InputDecoration(
                  labelText: 'New qualification (e.g., M.Tech)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _add,
                  ),
                ),
                onSubmitted: (_) => _add(),
              ),
            ],
          ),
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

// --- SHARED HELPER WIDGETS ---
class _ProfileHeader extends StatelessWidget {
  final UserAccount user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleChip = Chip(
      label: Text(user.role.label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w700)),
      backgroundColor: Theme.of(context).colorScheme.primary,
      visualDensity: VisualDensity.compact,
    );

    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
            child: Text(user.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Center(child: roleChip),
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
      title: 'Settings',
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.lock_reset),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showChangePasswordDialog(context, ref, user.email!),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () async {
            await ref.read(authRepoProvider).logout();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
          },
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, WidgetRef ref, String email) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Text('A password reset link will be sent to your email: $email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(authRepoProvider).requestPasswordReset(email);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset link sent.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                // --- FIX: Use the error parser ---
                final message = FirebaseErrorParser.getMessage(e);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $message')),
                );
                // --- End of Fix ---
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroupCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  const _InfoTile({required this.icon, required this.title, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: trailing ?? Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatItem({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}