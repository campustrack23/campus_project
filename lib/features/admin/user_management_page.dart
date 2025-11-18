// lib/features/admin/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../main.dart'; // Import main.dart to get the global provider

class UserManagementPage extends ConsumerStatefulWidget {
  final bool addStudentOnOpen;
  const UserManagementPage({super.key, this.addStudentOnOpen = false});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  String _query = '';
  bool _openedAddOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.addStudentOnOpen && !_openedAddOnce) {
      _openedAddOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddDialog(initialRole: UserRole.student);
      });
    }
  }

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
          title: const Text('User Management'),
          bottom: const TabBar(isScrollable: true, tabs: tabs),
          actions: [
            const ProfileAvatarAction(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(allUsersProvider)),
            IconButton(icon: const Icon(Icons.person_add), onPressed: () => _showAddDialog()),
          ],
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name / CR / ER / phone / email',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _UserList(list: _filter(studentsByYear(1)), onDataChanged: () async => ref.invalidate(allUsersProvider)),
                      _UserList(list: _filter(studentsByYear(2)), onDataChanged: () async => ref.invalidate(allUsersProvider)),
                      _UserList(list: _filter(studentsByYear(3)), onDataChanged: () async => ref.invalidate(allUsersProvider)),
                      _UserList(list: _filter(studentsByYear(4)), onDataChanged: () async => ref.invalidate(allUsersProvider)),
                      _UserList(list: _filter(teachers), onDataChanged: () async => ref.invalidate(allUsersProvider)),
                      _UserList(list: _filter(admins), onDataChanged: () async => ref.invalidate(allUsersProvider)),
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
          (u.section ?? '').toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          u.role.label.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _showAddDialog({UserRole initialRole = UserRole.teacher}) async {
    final auth = ref.read(authRepoProvider);
    final users = ref.read(allUsersProvider).value ?? [];
    final existingSections = users.map((u) => u.section).whereType<String>().toSet().toList()..sort();

    final form = GlobalKey<FormState>();
    UserRole role = initialRole;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final collegeCtrl = TextEditingController();
    final examCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    String? section = existingSections.isNotEmpty ? existingSections.first : null;
    int? year;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Add User'),
            content: Form(
              key: form,
              child: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<UserRole>(
                        initialValue: role,
                        items: const [
                          DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                          DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
                          DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                        ],
                        onChanged: (v) => setModalState(() => role = v ?? initialRole),
                        decoration: const InputDecoration(labelText: 'Role'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 8),
                      TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 8),
                      TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || v.trim().isEmpty || !v.contains('@')) ? 'Valid email is required' : null),
                      const SizedBox(height: 8),
                      if (role == UserRole.student) ...[
                        TextFormField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College Roll No.'), keyboardType: TextInputType.number),
                        const SizedBox(height: 8),
                        TextFormField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Exam Roll No.'), keyboardType: TextInputType.number),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: year,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1st Year')),
                            DropdownMenuItem(value: 2, child: Text('2nd Year')),
                            DropdownMenuItem(value: 3, child: Text('3rd Year')),
                            DropdownMenuItem(value: 4, child: Text('4th Year')),
                          ],
                          onChanged: (v) => setModalState(() => year = v),
                          decoration: const InputDecoration(labelText: 'Year'),
                          validator: (v) => v == null ? 'Year is required' : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: section,
                          items: existingSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setModalState(() => section = v),
                          decoration: const InputDecoration(labelText: 'Section'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Section is required' : null,
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: pwdCtrl,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      try {
        await auth.createUser(
          role: role,
          name: nameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          password: pwdCtrl.text.trim(),
          collegeRollNo: role == UserRole.student ? (collegeCtrl.text.trim().isEmpty ? null : collegeCtrl.text.trim()) : null,
          examRollNo: role == UserRole.student ? (examCtrl.text.trim().isEmpty ? null : examCtrl.text.trim()) : null,
          year: role == UserRole.student ? year : null,
          section: role == UserRole.student ? section : null,
        );
        ref.invalidate(allUsersProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create user: $e')));
      }
    }

    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    pwdCtrl.dispose();
    collegeCtrl.dispose();
    examCtrl.dispose();
    sectionCtrl.dispose();
  }
}

class _UserList extends ConsumerWidget {
  final List<UserAccount> list;
  final Future<void> Function() onDataChanged;
  const _UserList({required this.list, required this.onDataChanged});

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
          leading: CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')),
          title: Text('${u.name} • ${u.role.label}'),
          subtitle: Text([
            if (ids.isNotEmpty) ids,
            'Phone: ${u.phone}',
            if (u.email != null && u.email!.isNotEmpty) 'Email: ${u.email}',
            if (u.role == UserRole.student && u.year != null) 'Year ${u.year}',
            if ((u.section ?? '').isNotEmpty) 'Section: ${u.section}',
          ].where((x) => x.isNotEmpty).join('  •  ')),
          trailing: Switch(
            value: u.isActive,
            onChanged: (v) async {
              await ref.read(authRepoProvider).setActive(u.id, v);
              await onDataChanged();
            },
          ),
          onTap: () => _editUser(context, ref, u),
        );
      },
    );
  }

  Future<void> _editUser(BuildContext context, WidgetRef ref, UserAccount u) async {
    final users = ref.read(allUsersProvider).value ?? [];
    final existingSections = users.map((u) => u.section).whereType<String>().toSet().toList()..sort();

    final nameCtrl = TextEditingController(text: u.name);
    final phoneCtrl = TextEditingController(text: u.phone);
    final emailCtrl = TextEditingController(text: u.email ?? '');
    final collegeCtrl = TextEditingController(text: u.collegeRollNo ?? '');
    final examCtrl = TextEditingController(text: u.examRollNo ?? '');
    int? year = u.year;
    String? section = u.section;

    final form = GlobalKey<FormState>();
    final updated = await showDialog<UserAccount>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit User'),
        content: Form(
          key: form,
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 8),
                  TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 8),
                  TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, enabled: false), // Email cannot be changed
                  const SizedBox(height: 8),
                  if (u.role == UserRole.student) ...[
                    TextFormField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College Roll No.'), keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    TextFormField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Exam Roll No.'), keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: year,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1st Year')),
                        DropdownMenuItem(value: 2, child: Text('2nd Year')),
                        DropdownMenuItem(value: 3, child: Text('3rd Year')),
                        DropdownMenuItem(value: 4, child: Text('4th Year')),
                      ],
                      onChanged: (v) => year = v,
                      decoration: const InputDecoration(labelText: 'Year'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: section,
                      items: existingSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => section = v,
                      decoration: const InputDecoration(labelText: 'Section'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(
                context,
                u.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  collegeRollNo: collegeCtrl.text.trim().isEmpty ? null : collegeCtrl.text.trim(),
                  examRollNo: examCtrl.text.trim().isEmpty ? null : examCtrl.text.trim(),
                  section: section,
                  year: u.role == UserRole.student ? (year ?? u.year) : null,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != null) {
      await ref.read(authRepoProvider).updateUser(updated);
      await onDataChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated')));
    }
  }
}
