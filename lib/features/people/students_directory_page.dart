// lib/features/people/students_directory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/models/remark.dart';
import '../../main.dart';

final directoryProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final allStudents = await authRepo.allStudents();

  List<StudentRemark> remarks = [];
  if (me.role == UserRole.teacher) {
    final remarkRepo = ref.watch(remarkRepoProvider);
    remarks = await remarkRepo.forTeacher(me.id);
  }

  return {
    'me': me,
    'students': allStudents,
    'remarks': remarks,
  };
});

class StudentsDirectoryPage extends ConsumerStatefulWidget {
  final int initialYear;
  const StudentsDirectoryPage({super.key, this.initialYear = 4});

  @override
  ConsumerState<StudentsDirectoryPage> createState() => _StudentsDirectoryPageState();
}

class _StudentsDirectoryPageState extends ConsumerState<StudentsDirectoryPage> {
  int _year = 4;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(directoryProvider);

    return Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Text('Students • Year $_year'),
          actions: const [ProfileAvatarAction()],
        ),
        drawer: const AppDrawer(),
        body: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // --- FIX: Use the new error widget ---
          error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(directoryProvider),
          ),
          // --- End of Fix ---
          data: (data) {
            final me = data['me'] as UserAccount;
            final allStudents = data['students'] as List<UserAccount>;
            final remarks = data['remarks'] as List<StudentRemark>;

            final isAdmin = me.role == UserRole.admin;
            final isTeacher = me.role == UserRole.teacher;

            final students = allStudents.where((s) => (s.year ?? 4) == _year).toList()
              ..sort((a, b) => (a.collegeRollNo ?? '').compareTo(b.collegeRollNo ?? ''));

            final filtered = students.where((s) {
              if (_q.isEmpty) return true;
              final q = _q.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  (s.collegeRollNo ?? '').contains(q) ||
                  (s.examRollNo ?? '').contains(q) ||
                  (s.section ?? '').toLowerCase().contains(q) ||
                  s.phone.contains(q);
            }).toList();

            final tagByStudent = { for (final r in remarks) r.studentId: r.tag };

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _yearChip(1), const SizedBox(width: 6),
                      _yearChip(2), const SizedBox(width: 6),
                      _yearChip(3), const SizedBox(width: 6),
                      _yearChip(4),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name / CR / ER / section / phone'),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No students found'))
                      : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final ids = [
                        if (s.collegeRollNo != null) 'CR: ${s.collegeRollNo}',
                        if (s.examRollNo != null) 'ER: ${s.examRollNo}',
                      ].join('  •  ');

                      final tag = isTeacher ? (tagByStudent[s.id] ?? '') : '';

                      return ListTile(
                        leading: CircleAvatar(child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')),
                        title: Text([
                          s.name,
                          if ((s.collegeRollNo ?? '').isNotEmpty) '• ${s.collegeRollNo}',
                        ].join('  ')),
                        subtitle: Text([
                          if (ids.isNotEmpty) ids,
                          s.phone,
                          if ((s.section ?? '').isNotEmpty) s.section!,
                        ].where((x) => x.isNotEmpty).join('  •  ')),
                        trailing: isTeacher
                            ? InputChip(
                          avatar: const Icon(Icons.label_important_outline, size: 18),
                          label: Text(tag.isEmpty ? 'Add tag' : tag),
                          onPressed: () async {
                            final newTag = await _pickTag(context, tag);
                            if (newTag == null) return;
                            await ref.read(remarkRepoProvider).upsertRemark(teacherId: me.id, studentId: s.id, tag: newTag);
                            ref.invalidate(directoryProvider);
                          },
                          onDeleted: tag.isEmpty
                              ? null
                              : () async {
                            await ref.read(remarkRepoProvider).upsertRemark(teacherId: me.id, studentId: s.id, tag: '');
                            ref.invalidate(directoryProvider);
                          },
                        )
                            : (isAdmin
                            ? Switch(
                          value: s.isActive,
                          onChanged: (v) async {
                            await ref.read(authRepoProvider).setActive(s.id, v);
                            ref.invalidate(directoryProvider);
                          },
                        )
                            : null),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        )
    );
  }

  Widget _yearChip(int y) => ChoiceChip(
    label: Text('$y${y == 1 ? 'st' : y == 2 ? 'nd' : y == 3 ? 'rd' : 'th'} Year'),
    selected: _year == y,
    onSelected: (_) => setState(() => _year = y),
  );

  Future<String?> _pickTag(BuildContext context, String? current) async {
    String? selected = current?.isEmpty == true ? null : current;
    final customCtrl = TextEditingController(
      text: (selected == null || selected == 'Good' || selected == 'Average' || selected == 'Needs Improvement') ? '' : selected,
    );
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + (bottomInset > 0 ? bottomInset : 8)),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Set Student Tag (private)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('Good'), selected: selected == 'Good', onSelected: (_) => setModalState(() => selected = 'Good')),
                      ChoiceChip(label: const Text('Average'), selected: selected == 'Average', onSelected: (_) => setModalState(() => selected = 'Average')),
                      ChoiceChip(label: const Text('Needs Improvement'), selected: selected == 'Needs Improvement', onSelected: (_) => setModalState(() => selected = 'Needs Improvement')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: customCtrl, decoration: const InputDecoration(labelText: 'Custom tag (optional)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final custom = customCtrl.text.trim();
                          if (custom.isNotEmpty) {
                            selected = custom;
                          }
                          Navigator.pop(context, selected ?? '');
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}