// lib/features/admin/internal_marks_overrides_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/internal_marks.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../main.dart';

// Provider to fetch all data needed for this page
final adminMarksProvider = FutureProvider.autoDispose((ref) async {
  final marksRepo = ref.read(internalMarksRepoProvider);
  final ttRepo = ref.read(timetableRepoProvider);
  final authRepo = ref.read(authRepoProvider);
  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final results = await Future.wait([
    marksRepo.getAllMarks(),
    ttRepo.allSubjects(),
    authRepo.allStudents(),
  ]);

  final marks = results[0] as List<InternalMarks>;
  final subjects = results[1] as List<Subject>;
  final students = results[2] as List<UserAccount>;

  return {
    'me': me,
    'marks': marks..sort((a, b) => a.studentId.compareTo(b.studentId)),
    'subjects': subjects,
    'students': students,
  };
});

class InternalMarksOverridesPage extends ConsumerStatefulWidget {
  const InternalMarksOverridesPage({super.key});

  @override
  ConsumerState<InternalMarksOverridesPage> createState() =>
      _InternalMarksOverridesPageState();
}

class _InternalMarksOverridesPageState
    extends ConsumerState<InternalMarksOverridesPage> {
  String? _subjectId;
  String _query = '';
  final Map<String, InternalMarks> _editedMarks = {};

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(adminMarksProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Internal Marks Overrides'),
        actions: [
          const ProfileAvatarAction(),
          IconButton(
            onPressed: () => ref.invalidate(adminMarksProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminMarksProvider),
        ),
        data: (data) {
          final me = data['me'] as UserAccount;
          final allMarks = data['marks'] as List<InternalMarks>;
          final allSubjects = data['subjects'] as List<Subject>;
          final allStudents = data['students'] as List<UserAccount>;

          final subjectsMap = {for (final s in allSubjects) s.id: s};
          final studentsMap = {for (final s in allStudents) s.id: s};

          // Merge edited marks with original
          final combinedMarks = {
            for (final m in allMarks) m.id: m,
            ..._editedMarks,
          };

          final filtered = combinedMarks.values.where((m) {
            // --- FIX: HIDE DATA UNTIL SUBJECT IS SELECTED ---
            if (_subjectId == null) return false;
            if (m.subjectId != _subjectId) return false;
            // ------------------------------------------------

            final stu = studentsMap[m.studentId];
            if (stu == null) return false;

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final nameMatch = stu.name.toLowerCase().contains(q);
              final crMatch = (stu.collegeRollNo ?? '').toLowerCase().contains(q);

              if (!nameMatch && !crMatch) return false;
            }

            return true;
          }).toList()
            ..sort((a, b) {
              final nameA = studentsMap[a.studentId]?.name ?? '';
              final nameB = studentsMap[b.studentId]?.name ?? '';
              return nameA.compareTo(nameB);
            });

          final subjectList = subjectsMap.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return Column(
            children: [
              // FILTERS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Subject dropdown
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String?>(
                        value: _subjectId, // Use 'value' not 'initialValue' for reactive updates
                        isExpanded: true,
                        hint: const Text('Select Subject (Required)'),
                        items: subjectList.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.code} - ${s.name} (${s.section})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _subjectId = v),
                        decoration: const InputDecoration(
                          labelText: 'Filter by Subject',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    // Search
                    SizedBox(
                      width: 300,
                      child: TextField(
                        onChanged: (value) => setState(() => _query = value),
                        // Disable search if no subject selected
                        enabled: _subjectId != null,
                        decoration: const InputDecoration(
                          labelText: 'Search by name or CR',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 0),

              // LIST
              Expanded(
                child: _subjectId == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_upward, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Please select a subject above to view student marks.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
                    : filtered.isEmpty
                    ? const Center(child: Text('No marks found for this subject.'))
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final marks = filtered[i];
                    final subj = subjectsMap[marks.subjectId];
                    final stu = studentsMap[marks.studentId];

                    if (stu == null || subj == null) {
                      return const SizedBox.shrink();
                    }

                    return ExpansionTile(
                      leading: CircleAvatar(
                        child: Text(
                          stu.name.isNotEmpty
                              ? stu.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(
                        '${stu.name}  •  CR: ${stu.collegeRollNo ?? 'N/A'}',
                      ),
                      subtitle: Text(subj.name),
                      trailing: Text(
                        '${marks.totalMarks.toStringAsFixed(0)} / 30',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        _EditMarksForm(
                          marks: marks,
                          onSave: (assign, test, attendance) {
                            final updated = marks.copyWith(
                              assignmentMarks: assign,
                              testMarks: test,
                              attendanceMarks: attendance,
                              updatedAt: DateTime.now(),
                              teacherId: me.id,
                            );

                            setState(() {
                              _editedMarks[updated.id] = updated;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              // SAVE BAR
              if (_editedMarks.isNotEmpty)
                _SaveChangesBar(
                  count: _editedMarks.length,
                  onCancel: () => setState(() => _editedMarks.clear()),
                  onSave: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final repo = ref.read(internalMarksRepoProvider);

                    for (final marks in _editedMarks.values) {
                      await repo.updateMarks(marks);
                    }

                    setState(() => _editedMarks.clear());
                    ref.invalidate(adminMarksProvider);

                    messenger.showSnackBar(
                      const SnackBar(content: Text('Changes saved')),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// MARK INPUT FORM
class _EditMarksForm extends StatefulWidget {
  final InternalMarks marks;
  final Function(double assignment, double test, double attendance) onSave;

  const _EditMarksForm({required this.marks, required this.onSave});

  @override
  State<_EditMarksForm> createState() => _EditMarksFormState();
}

class _EditMarksFormState extends State<_EditMarksForm> {
  late TextEditingController _assignCtrl;
  late TextEditingController _testCtrl;
  late TextEditingController _attCtrl;

  @override
  void initState() {
    super.initState();
    _assignCtrl =
        TextEditingController(text: widget.marks.assignmentMarks.toStringAsFixed(0));
    _testCtrl =
        TextEditingController(text: widget.marks.testMarks.toStringAsFixed(0));
    _attCtrl =
        TextEditingController(text: widget.marks.attendanceMarks.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _assignCtrl.dispose();
    _testCtrl.dispose();
    _attCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    FocusScope.of(context).unfocus();
    final assign = (double.tryParse(_assignCtrl.text) ?? 0.0).clamp(0.0, 12.0);
    final test = (double.tryParse(_testCtrl.text) ?? 0.0).clamp(0.0, 12.0);
    final att = (double.tryParse(_attCtrl.text) ?? 0.0).clamp(0.0, 6.0);

    // Update UI to show clamped/parsed values
    _assignCtrl.text = assign.toStringAsFixed(0);
    _testCtrl.text = test.toStringAsFixed(0);
    _attCtrl.text = att.toStringAsFixed(0);

    widget.onSave(assign, test, att);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _MarkInput(label: 'Assignment', max: 12, controller: _assignCtrl),
              _MarkInput(label: 'Test/PPT', max: 12, controller: _testCtrl),
              _MarkInput(label: 'Attendance', max: 6, controller: _attCtrl),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Update Marks'),
              onPressed: _onSave,
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable mark input widget
class _MarkInput extends StatelessWidget {
  final String label;
  final int max;
  final TextEditingController controller;

  const _MarkInput({
    required this.label,
    required this.max,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: '$label (/$max)'),
      ),
    );
  }
}

// Save bar widget
class _SaveChangesBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _SaveChangesBar({
    required this.count,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count unsaved change(s)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onSave, child: const Text('Save All')),
            ],
          ),
        ],
      ),
    );
  }
}