// lib/features/people/students_directory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../core/models/remark.dart';
import '../../main.dart';

// -------------------- PROVIDER --------------------
final directoryProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final allStudents = await authRepo.allStudents();

  List<StudentRemark> remarks = [];
  // Only fetch remarks if the user is a teacher
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

// =====================================================
//               STUDENTS DIRECTORY PAGE
// =====================================================
class StudentsDirectoryPage extends ConsumerStatefulWidget {
  final int initialYear;
  const StudentsDirectoryPage({super.key, this.initialYear = 1});

  @override
  ConsumerState<StudentsDirectoryPage> createState() => _StudentsDirectoryPageState();
}

class _StudentsDirectoryPageState extends ConsumerState<StudentsDirectoryPage> {
  late int _year;
  String _q = '';
  String _alpha = 'ALL';

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
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(directoryProvider),
        ),
        data: (data) {
          final me = data['me'] as UserAccount;
          final allStudents = data['students'] as List<UserAccount>;
          final remarks = data['remarks'] as List<StudentRemark>;

          final isAdmin = me.role == UserRole.admin;
          final isTeacher = me.role == UserRole.teacher;

          // Filter by year
          final students = allStudents.where((s) => (s.year ?? 1) == _year).toList()
            ..sort((a, b) => (a.collegeRollNo ?? '').compareTo(b.collegeRollNo ?? ''));

          // Filter by search query
          final filteredSearch = students.where((s) {
            if (_q.isEmpty) return true;
            final q = _q.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                (s.collegeRollNo ?? '').contains(q) ||
                (s.examRollNo ?? '').contains(q) ||
                (s.section ?? '').toLowerCase().contains(q) ||
                s.phone.contains(q);
          }).toList();

          // Alphabetic filter
          final filtered = (_alpha == 'ALL')
              ? filteredSearch
              : filteredSearch.where((s) => s.name.isNotEmpty && s.name.toUpperCase().startsWith(_alpha)).toList();

          // Map studentId to remark tag
          final tagByStudent = {for (final r in remarks) r.studentId: r.tag};

          return Column(
            children: [
              // Year filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    for (final y in [1, 2, 3, 4]) ...[
                      _yearChip(y),
                      const SizedBox(width: 8),
                    ]
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by Name, Roll No, Section, or Phone',
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),

              // Alphabet filter
              _buildAlphabetFilter(),

              // Student list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No students found', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final ids = [
                      if (s.collegeRollNo != null) 'CR: ${s.collegeRollNo}',
                      if (s.section != null) 'Sec: ${s.section}',
                    ].join(' • ');

                    final tag = isTeacher ? (tagByStudent[s.id] ?? '') : '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ids.isNotEmpty) Text(ids),
                          Text(s.phone, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      trailing: isTeacher
                          ? ActionChip(
                        avatar: Icon(Icons.label, size: 16, color: Theme.of(context).colorScheme.primary),
                        label: Text(tag.isEmpty ? 'Add Remark' : tag),
                        backgroundColor: tag.isNotEmpty ? Theme.of(context).colorScheme.primaryContainer : null,
                        onPressed: () async {
                          final newTag = await _pickTag(context, tag);
                          if (newTag == null) return;
                          await ref.read(remarkRepoProvider).upsertRemark(
                            teacherId: me.id,
                            studentId: s.id,
                            tag: newTag,
                          );
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
      ),
    );
  }

  Widget _yearChip(int y) => ChoiceChip(
    label: Text('$y${y == 1 ? 'st' : y == 2 ? 'nd' : y == 3 ? 'rd' : 'th'} Year'),
    selected: _year == y,
    onSelected: (_) => setState(() => _year = y),
    showCheckmark: false,
  );

  Widget _buildAlphabetFilter() {
    final letters = ['ALL', ...List.generate(26, (i) => String.fromCharCode(65 + i))];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final l = letters[i];
          return ChoiceChip(
            label: Text(l),
            selected: _alpha == l,
            onSelected: (_) => setState(() => _alpha = l),
          );
        },
      ),
    );
  }

  Future<String?> _pickTag(BuildContext context, String? current) async {
    String? selected = (current?.isEmpty ?? true) ? null : current;
    final customCtrl = TextEditingController(
      text: (selected == null ||
          ['Good', 'Average', 'Needs Improvement'].contains(selected))
          ? ''
          : selected,
    );

    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + (bottomInset > 0 ? bottomInset : 8)),
          child: StatefulBuilder(
            builder: (BuildContext context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Set Student Tag (private)',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                          label: const Text('Good'),
                          selected: selected == 'Good',
                          onSelected: (_) => setModalState(() => selected = 'Good')),
                      ChoiceChip(
                          label: const Text('Average'),
                          selected: selected == 'Average',
                          onSelected: (_) => setModalState(() => selected = 'Average')),
                      ChoiceChip(
                          label: const Text('Needs Improvement'),
                          selected: selected == 'Needs Improvement',
                          onSelected: (_) => setModalState(() => selected = 'Needs Improvement')),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: customCtrl,
                    decoration: const InputDecoration(labelText: 'Custom tag (optional)'),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
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
