// lib/features/admin/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../main.dart';

// DEFINED HERE TO FIX "Undefined name" ERROR
final allUsersProvider = FutureProvider.autoDispose<List<UserAccount>>((ref) async {
  return ref.watch(authRepoProvider).allUsers();
});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: asyncUsers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => AsyncErrorWidget(
                // Removed 'const' if causing issues, though here it might be fine depending on imports
                message: err.toString(),
                onRetry: () => ref.refresh(allUsersProvider),
              ),
              data: (users) {
                final filtered = users.where((u) {
                  return u.name.toLowerCase().contains(_query.toLowerCase()) ||
                      (u.email?.contains(_query) ?? false) ||
                      (u.collegeRollNo?.contains(_query) ?? false);
                }).toList();

                if (filtered.isEmpty) return const Center(child: Text('No users found'));

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(u.name.isNotEmpty ? u.name[0] : '?'),
                      ),
                      title: Text(u.name),
                      subtitle: Text('${u.role.label} • ${u.email ?? u.phone}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(u),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog({UserRole? initialRole}) async {
    final newId = const Uuid().v4();
    final newUser = UserAccount(
      id: newId,
      role: initialRole ?? UserRole.student,
      name: '',
      email: '',
      phone: '',
      // FIXED: Removed passwordHash: ''
      createdAt: DateTime.now(),
      isActive: true, // explicit default
    );
    await _showEditDialog(newUser, isNew: true);
  }

  Future<void> _showEditDialog(UserAccount u, {bool isNew = false}) async {
    final form = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: u.name);
    final emailCtrl = TextEditingController(text: u.email);
    final phoneCtrl = TextEditingController(text: u.phone);
    final collegeCtrl = TextEditingController(text: u.collegeRollNo);
    final examCtrl = TextEditingController(text: u.examRollNo);

    String section = u.section ?? 'IV-HE';
    int? year = u.year ?? 4;
    UserRole role = u.role;
    final existingSections = ['I-HE', 'II-HE', 'III-HE', 'IV-HE'];

    final passCtrl = TextEditingController();

    final updated = await showDialog<UserAccount>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isNew ? 'Add User' : 'Edit User'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNew) ...[
                    DropdownButtonFormField<UserRole>(
                      initialValue: role,
                      items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                      onChanged: (v) => setState(() => role = v!),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  if (isNew) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                    ),
                  ],
                  if (role == UserRole.student) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College Roll'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Exam Roll'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: year,
                            items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('$y Year'))).toList(),
                            onChanged: (v) => year = v,
                            decoration: const InputDecoration(labelText: 'Year'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: existingSections.contains(section) ? section : null,
                            items: existingSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => section = v!,
                            decoration: const InputDecoration(labelText: 'Section'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
                    id: isNew ? u.id : u.id,
                    role: role,
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    collegeRollNo: collegeCtrl.text.trim().isEmpty ? null : collegeCtrl.text.trim(),
                    examRollNo: examCtrl.text.trim().isEmpty ? null : examCtrl.text.trim(),
                    section: role == UserRole.student ? section : null,
                    year: role == UserRole.student ? year : null,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated != null) {
      if (isNew) {
        if (!context.mounted) return; // Guard for context use
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use Seeder or Sign Up page to create new Auth accounts.')));
        await ref.read(authRepoProvider).updateUser(updated);
      } else {
        await ref.read(authRepoProvider).updateUser(updated);
      }
      ref.invalidate(allUsersProvider);
    }
  }
}