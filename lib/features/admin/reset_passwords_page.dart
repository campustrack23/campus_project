// lib/features/admin/reset_passwords_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../main.dart'; // Import main.dart to get the global provider

class ResetPasswordsPage extends ConsumerStatefulWidget {
  const ResetPasswordsPage({super.key});

  @override
  ConsumerState<ResetPasswordsPage> createState() => _ResetPasswordsPageState();
}

class _ResetPasswordsPageState extends ConsumerState<ResetPasswordsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncUsers = ref.watch(allUsersProvider);

    const tabs = [
      Tab(text: '1st Year'),
      Tab(text: '2nd Year'),
      Tab(text: '3rd Year'),
      Tab(text: '4th Year'),
      Tab(text: 'Teachers'),
      Tab(text: 'Admins'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Reset Passwords'),
          bottom: const TabBar(isScrollable: true, tabs: tabs),
          actions: const [ProfileAvatarAction()],
        ),
        drawer: const AppDrawer(),
        body: asyncUsers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // --- FIX: Use the new error widget ---
          error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(allUsersProvider),
          ),
          // --- End of Fix ---
          data: (users) {
            List<UserAccount> studentsByYear(int year) =>
                users.where((u) => u.role == UserRole.student && u.year == year).toList()
                  ..sort((a, b) => (a.collegeRollNo ?? '').compareTo(b.collegeRollNo ?? ''));

            final teachers = users.where((u) => u.role == UserRole.teacher).toList()
              ..sort((a, b) => (a.name).compareTo(b.name));
            final admins = users.where((u) => u.role == UserRole.admin).toList()
              ..sort((a, b) => (a.name).compareTo(b.name));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search users'),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ResetList(list: _filter(studentsByYear(1)), onReset: _reset),
                      _ResetList(list: _filter(studentsByYear(2)), onReset: _reset),
                      _ResetList(list: _filter(studentsByYear(3)), onReset: _reset),
                      _ResetList(list: _filter(studentsByYear(4)), onReset: _reset),
                      _ResetList(list: _filter(teachers), onReset: _reset),
                      _ResetList(list: _filter(admins), onReset: _reset),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<UserAccount> _filter(List<UserAccount> list) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list.where((u) {
      return u.name.toLowerCase().contains(q) ||
          (u.collegeRollNo ?? '').toLowerCase().contains(q) ||
          (u.examRollNo ?? '').toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _reset(BuildContext context, UserAccount u) async {
    if (u.email == null || u.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This user does not have an email to send a reset link to.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset ${u.name}\'s password?'),
        content: Text('A password reset link will be sent to ${u.email}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Link')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(authRepoProvider).requestPasswordReset(u.email!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}

class _ResetList extends ConsumerWidget {
  final List<UserAccount> list;
  final Future<void> Function(BuildContext, UserAccount) onReset;
  const _ResetList({required this.list, required this.onReset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) return const Center(child: Text('No users found'));
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final u = list[i];
        final ids = [
          if (u.collegeRollNo != null) 'CR: ${u.collegeRollNo}',
          if (u.examRollNo != null) 'ER: ${u.examRollNo}',
        ].join('  •  ');
        return ListTile(
          leading: const Icon(Icons.lock_reset),
          title: Text(u.name),
          subtitle: Text('${u.role.label} • ${u.email ?? u.phone}${ids.isNotEmpty ? ' • $ids' : ''}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => onReset(context, u),
        );
      },
    );
  }
}