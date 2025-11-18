// lib/features/teacher/remarks_board_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
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
  int _year = 4;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(remarksBoardProvider);

    return Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Remarks Board'),
          actions: const [ProfileAvatarAction()],
        ),
        drawer: const AppDrawer(),
        body: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // --- FIX: Use the new error widget ---
          error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(remarksBoardProvider),
          ),
          // --- End of Fix ---
          data: (data) {
            final me = data['me'] as UserAccount;
            final remarks = data['remarks'] as List<StudentRemark>;
            final allStudents = data['students'] as List<UserAccount>;
            final students = { for (final s in allStudents) s.id: s };

            final tagSet = <String>{...remarks.map((r) => r.tag).where((t) => t.trim().isNotEmpty)};
            final tags = ['All', ...tagSet.toList()..sort()];

            final filtered = remarks.where((r) {
              final s = students[r.studentId];
              if (s == null) return false;
              final matchYear = (s.year ?? 4) == _year;
              final matchTag = _filterTag == 'All' || r.tag == _filterTag;
              final q = _q.toLowerCase();
              final matchQ = q.isEmpty || s.name.toLowerCase().contains(q) ||
                  (s.collegeRollNo ?? '').contains(q) ||
                  (s.examRollNo ?? '').contains(q) ||
                  s.phone.contains(q);
              return matchYear && matchTag && matchQ;
            }).toList()
              ..sort((a, b) => (students[a.studentId]?.collegeRollNo ?? '').compareTo(students[b.studentId]?.collegeRollNo ?? ''));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _yearChip(1), const SizedBox(width: 6),
                      _yearChip(2), const SizedBox(width: 6),
                      _yearChip(3), const SizedBox(width: 6),
                      _yearChip(4),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: tags.map((t) {
                      final sel = _filterTag == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t),
                          selected: sel,
                          onSelected: (_) => setState(() => _filterTag = t),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name / CR / ER / phone'),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(remarksBoardProvider),
                    child: filtered.isEmpty
                        ? const Center(child: Text('No remarks found'))
                        : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final s = students[r.studentId]!;
                        return ListTile(
                          leading: CircleAvatar(child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')),
                          title: Text([
                            s.name,
                            if ((s.collegeRollNo ?? '').isNotEmpty) '• ${s.collegeRollNo}',
                          ].join('  ')),
                          subtitle: Text('ER: ${s.examRollNo ?? '-'} • ${s.phone}'),
                          trailing: InputChip(
                            label: Text(r.tag.isEmpty ? 'Set tag' : r.tag),
                            onPressed: () => _handleTagEdit(me, s, r.tag),
                            onDeleted: r.tag.isEmpty ? null : () => _handleTagEdit(me, s, ''),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        )
    );
  }

  Future<void> _handleTagEdit(UserAccount me, UserAccount student, String currentTag) async {
    final newTag = await _pickTag(context, currentTag);
    if (newTag == null) return;
    await ref.read(remarkRepoProvider).upsertRemark(teacherId: me.id, studentId: student.id, tag: newTag);
    ref.invalidate(remarksBoardProvider); // Refresh data
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
                  const Text('Edit Tag', style: TextStyle(fontWeight: FontWeight.w800)),
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
                          if (custom.isNotEmpty) selected = custom;
                          Navigator.pop(context, selected);
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