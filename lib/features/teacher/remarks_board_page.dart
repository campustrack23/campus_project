// lib/features/teacher/remarks_board_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/user.dart';
import '../../core/models/remark.dart';
import '../../main.dart';

final remarksBoardProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final remarkRepo = ref.watch(remarkRepoProvider);
  final remarks = await remarkRepo.forTeacher(me.id);
  final students = await authRepo.allStudents();

  return {
    'me': me,
    'remarks': remarks,
    'students': students,
  };
});

class RemarksBoardPage extends ConsumerStatefulWidget {
  const RemarksBoardPage({super.key});

  @override
  ConsumerState<RemarksBoardPage> createState() => _RemarksBoardPageState();
}

class _RemarksBoardPageState extends ConsumerState<RemarksBoardPage> {
  String _q = '';
  String _filterTag = 'All';
  int _year = 0; // 0=All

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(remarksBoardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remarks Board'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(remarksBoardProvider),
        ),
        data: (data) {
          final remarks = data['remarks'] as List<StudentRemark>;
          final students = data['students'] as List<UserAccount>;
          final me = data['me'] as UserAccount;

          // Merge data
          final List<_RemarkItem> items = [];
          for (final r in remarks) {
            final s = students.firstWhere(
                  (u) => u.id == r.studentId,
              orElse: () => UserAccount(
                  id: '?',
                  role: me.role,
                  name: 'Unknown',
                  email: '',
                  phone: '',
                  createdAt: DateTime.now()
              ),
            );
            if (s.id != '?') {
              items.add(_RemarkItem(r, s));
            }
          }

          // Filter
          final filtered = items.where((i) {
            if (_year != 0 && i.student.year != _year) return false;
            if (_filterTag != 'All' && i.remark.tag != _filterTag) return false;
            if (_q.isNotEmpty && !i.student.name.toLowerCase().contains(_q.toLowerCase())) return false;
            return true;
          }).toList();

          // Get unique tags
          final tags = ['All', ...remarks.map((e) => e.tag).toSet()];

          return Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Student',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          DropdownButton<int>(
                            value: _year,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('All Years')),
                              DropdownMenuItem(value: 1, child: Text('1st Year')),
                              DropdownMenuItem(value: 2, child: Text('2nd Year')),
                              DropdownMenuItem(value: 3, child: Text('3rd Year')),
                              DropdownMenuItem(value: 4, child: Text('4th Year')),
                            ],
                            onChanged: (v) => setState(() => _year = v!),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: tags.contains(_filterTag) ? _filterTag : 'All',
                            items: tags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _filterTag = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No remarks found.'))
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    return ListTile(
                      leading: CircleAvatar(child: Text(item.student.name[0])),
                      title: Text(item.student.name),
                      subtitle: Text('${item.student.section ?? 'N/A'} • ${item.remark.tag}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () async {
                          await ref.read(remarkRepoProvider).deleteRemark(me.id, item.student.id);
                          ref.invalidate(remarksBoardProvider);
                        },
                      ),
                      onTap: () => _editRemark(context, ref, me.id, item.student),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // THE FIX: Uses asyncData to pass students and teacher to the new dialog
      floatingActionButton: asyncData.maybeWhen(
        data: (data) {
          final students = data['students'] as List<UserAccount>;
          final me = data['me'] as UserAccount;
          return FloatingActionButton.extended(
            onPressed: () => _showAddRemarkDialog(context, ref, students, me),
            label: const Text('Add Remark'),
            icon: const Icon(Icons.add),
          );
        },
        orElse: () => null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NEW ADD REMARK DIALOG WITH SEARCHABLE DROPDOWN
  // ---------------------------------------------------------------------------
  Future<void> _showAddRemarkDialog(
      BuildContext context,
      WidgetRef ref,
      List<UserAccount> allStudents,
      UserAccount me,
      ) async {
    UserAccount? selectedStudent;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add New Remark'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LayoutBuilder ensures DropdownMenu doesn't overflow the dialog
                LayoutBuilder(builder: (context, constraints) {
                  return DropdownMenu<UserAccount>(
                    width: constraints.maxWidth,
                    hintText: 'Search Student...',
                    enableFilter: true, // Enables searching!
                    requestFocusOnTap: true,
                    onSelected: (val) => selectedStudent = val,
                    dropdownMenuEntries: allStudents
                        .map((s) => DropdownMenuEntry<UserAccount>(
                      value: s,
                      label: '${s.name} (${s.collegeRollNo ?? 'N/A'})',
                    ))
                        .toList(),
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Remark / Tag',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedStudent == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select a student')),
                  );
                  return;
                }
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a remark')),
                  );
                  return;
                }

                try {
                  await ref.read(remarkRepoProvider).upsertRemark(
                    teacherId: me.id,
                    studentId: selectedStudent!.id,
                    tag: controller.text.trim(),
                  );
                  ref.invalidate(remarksBoardProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT EXISTING REMARK DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _editRemark(BuildContext context, WidgetRef ref, String teacherId, UserAccount student) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Remark for ${student.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Remark / Tag'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(remarkRepoProvider).upsertRemark(
                    teacherId: teacherId, studentId: student.id, tag: controller.text.trim()
                );
                ref.invalidate(remarksBoardProvider);
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _RemarkItem {
  final StudentRemark remark;
  final UserAccount student;
  _RemarkItem(this.remark, this.student);
}