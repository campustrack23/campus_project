// lib/features/admin/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/utils/firebase_error_parser.dart';
import '../../main.dart';

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
                message: err.toString(),
                onRetry: () => ref.invalidate(allUsersProvider),
              ),
              data: (users) {
                final filtered = users.where((u) {
                  return u.name.toLowerCase().contains(_query.toLowerCase()) ||
                      (u.email?.contains(_query) ?? false) ||
                      (u.collegeRollNo?.toLowerCase().contains(_query.toLowerCase()) ?? false);
                }).toList();

                if (filtered.isEmpty) return const Center(child: Text('No users found'));

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${u.role.label} • ${u.email ?? u.phone}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        color: Theme.of(context).colorScheme.primary,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
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
      createdAt: DateTime.now(),
      isActive: true,
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
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                  ),
                  if (isNew) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                    ),
                  ],
                  if (role == UserRole.student) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College Roll', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Exam Roll', border: OutlineInputBorder()))),
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
                            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: existingSections.contains(section) ? section : null,
                            items: existingSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => section = v!,
                            decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
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
            if (!isNew)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close the edit dialog
                  _confirmDeleteUser(u); // Open the secure delete dialog
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;

                Navigator.pop(
                  context,
                  u.copyWith(
                    id: u.id,
                    role: role,
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
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
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use Seeder or Sign Up page to create new Auth accounts.')));
        await ref.read(authRepoProvider).updateUser(updated);
      } else {
        await ref.read(authRepoProvider).updateUser(updated);
      }
      ref.invalidate(allUsersProvider);
    }
  }

  // ---------------------------------------------------------------------------
  // SECURE ADMIN DELETE FLOW
  // ---------------------------------------------------------------------------
  Future<void> _confirmDeleteUser(UserAccount user) async {
    final bool? deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminSecureDeleteDialog(user: user),
    );

    if (deleted == true) {
      ref.invalidate(allUsersProvider);
    }
  }
}

// -----------------------------------------------------------------------------
// SECURE DELETE DIALOG FOR ADMIN
// -----------------------------------------------------------------------------
class _AdminSecureDeleteDialog extends ConsumerStatefulWidget {
  final UserAccount user;
  const _AdminSecureDeleteDialog({required this.user});

  @override
  ConsumerState<_AdminSecureDeleteDialog> createState() => _AdminSecureDeleteDialogState();
}

class _AdminSecureDeleteDialogState extends ConsumerState<_AdminSecureDeleteDialog> {
  final TextEditingController _verifyCtrl = TextEditingController();
  bool _canDelete = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _verifyCtrl.addListener(() {
      setState(() {
        _canDelete = _verifyCtrl.text.trim() == 'DELETE';
      });
    });
  }

  @override
  void dispose() {
    _verifyCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeDelete() async {
    if (!_canDelete) return;

    setState(() => _isProcessing = true);

    try {
      // Deletes the user profile document securely without logging the Admin out
      await ref.read(authRepoProvider).deleteAccount(widget.user.id);

      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger UI refresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.name}\'s account deleted.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseErrorParser.getMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.person_remove_rounded, color: colorScheme.error, size: 48),
      title: const Text('Delete User Account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are about to permanently delete ${widget.user.name} (${widget.user.role.label}).',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          const Text(
            'This action will remove their profile and database access. It cannot be undone.',
            style: TextStyle(fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(color: colorScheme.onSurface),
              children: const [
                TextSpan(text: 'To confirm, type '),
                TextSpan(text: 'DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' below:'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _verifyCtrl,
            enabled: !_isProcessing,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'DELETE',
              filled: true,
              fillColor: colorScheme.errorContainer.withValues(alpha: 0.2),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.error, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.error.withValues(alpha: 0.5), width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _canDelete ? colorScheme.error : colorScheme.surfaceContainerHighest,
            foregroundColor: _canDelete ? colorScheme.onError : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onPressed: (_canDelete && !_isProcessing) ? _executeDelete : null,
          child: _isProcessing
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          )
              : const Text('Delete User'),
        ),
      ],
    );
  }
}