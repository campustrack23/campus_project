// lib/features/teacher/internal_marks_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart'; // For .firstWhereOrNull

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/user.dart';
import '../../core/models/subject.dart';
import '../../core/models/attendance.dart';
import '../../core/models/internal_marks.dart';
import '../../main.dart';

// Helper class to hold all the processed data
class SubjectGradingData {
  final UserAccount teacher;
  final Subject subject;
  final List<UserAccount> students;
  final Map<String, InternalMarks> marks; // key = studentId
  final Map<String, int> attendancePercentages; // key = studentId
  final bool isPublished;

  SubjectGradingData({
    required this.teacher,
    required this.subject,
    required this.students,
    required this.marks,
    required this.attendancePercentages,
    required this.isPublished,
  });
}

// Provider for fetching all subjects taught by the current teacher
final teacherSubjectsProvider = FutureProvider.autoDispose((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('Not logged in');

  final allSubjects = await ref.watch(timetableRepoProvider).allSubjects();
  return allSubjects.where((s) => s.teacherId == user.id).toList()..sort((a,b) => a.name.compareTo(b.name));
});

// Provider for fetching and processing all student data for a selected subject
final subjectGradingProvider = FutureProvider.autoDispose.family<SubjectGradingData, String>((ref, subjectId) async {
  final authRepo = ref.read(authRepoProvider);
  final attRepo = ref.read(attendanceRepoProvider);
  final marksRepo = ref.read(internalMarksRepoProvider);
  final ttRepo = ref.read(timetableRepoProvider);

  final teacher = await authRepo.currentUser();
  if (teacher == null) throw Exception('Not logged in');

  final subject = await ttRepo.subjectById(subjectId);
  if (subject == null) throw Exception('Subject not found');

  final students = await authRepo.studentsInSection(subject.section);
  final allAttendance = await attRepo.allRecords(); // Fetch all once
  final existingMarks = await marksRepo.getMarksForSubject(subjectId);

  final marksMap = {for (var m in existingMarks) m.studentId: m};
  final attendancePercentages = <String, int>{};

  for (final student in students) {
    final studentRecords = allAttendance
        .where((r) => r.studentId == student.id && r.subjectId == subjectId)
        .toList();

    final total = studentRecords.length;
    final present = studentRecords
        .where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused)
        .length;
    final pct = total == 0 ? 100 : ((present * 100) / total).round();
    attendancePercentages[student.id] = pct;
  }

  final isPublished = existingMarks.firstOrNull?.isVisibleToStudent ?? false;

  return SubjectGradingData(
    teacher: teacher,
    subject: subject,
    students: students..sort((a,b) => a.name.compareTo(b.name)),
    marks: marksMap,
    attendancePercentages: attendancePercentages,
    isPublished: isPublished,
  );
});


class InternalMarksPage extends ConsumerStatefulWidget {
  const InternalMarksPage({super.key});

  @override
  ConsumerState<InternalMarksPage> createState() => _InternalMarksPageState();
}

class _InternalMarksPageState extends ConsumerState<InternalMarksPage> {
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(teacherSubjectsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Internal Marks'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const Center(child: Text('You are not the lead teacher for any subjects.'));
                }
                return DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  hint: const Text('Select a subject to grade...'),
                  isExpanded: true,
                  items: subjects.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.section})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSubjectId = value);
                  },
                  decoration: const InputDecoration(labelText: 'Subject'),
                );
              },
            ),
          ),
          if (_selectedSubjectId != null)
            Expanded(
              child: _GradingList(subjectId: _selectedSubjectId!),
            )
          else
            const Expanded(
              child: Center(child: Text('Please select a subject to continue.')),
            ),
        ],
      ),
    );
  }
}

class _GradingList extends ConsumerWidget {
  final String subjectId;
  const _GradingList({required this.subjectId});

  int _calculateAttendanceMarks(int pct) {
    if (pct <= 75) return 0;
    if (pct <= 80) return 1;
    if (pct <= 85) return 2;
    if (pct <= 90) return 3;
    if (pct <= 95) return 4;
    if (pct <= 99) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(subjectGradingProvider(subjectId));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => AsyncErrorWidget(
        message: err.toString(),
        onRetry: () => ref.invalidate(subjectGradingProvider(subjectId)),
      ),
      data: (data) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SwitchListTile(
                title: const Text('Publish Marks to Students', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data.isPublished ? 'Students can see these marks' : 'Marks are hidden'),
                value: data.isPublished,
                onChanged: (isVisible) async {
                  // --- FIX: Show a confirmation dialog ---
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(isVisible ? 'Publish Marks?' : 'Hide Marks?'),
                      content: Text(isVisible
                          ? 'Are you sure you want to publish these marks? All ${data.students.length} students in this section will be able to see their grades.'
                          : 'Are you sure you want to hide these marks? Students will no longer be able to see them.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isVisible ? 'Publish' : 'Hide')),
                      ],
                    ),
                  );

                  if (confirm != true) return;
                  // --- End of Fix ---
                  await ref.read(internalMarksRepoProvider).publishMarksForSubject(subjectId, isVisible);
                  ref.invalidate(subjectGradingProvider(subjectId));
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: data.students.length,
                itemBuilder: (context, index) {
                  final student = data.students[index];
                  final attPct = data.attendancePercentages[student.id] ?? 0;
                  final attMarks = _calculateAttendanceMarks(attPct);
                  final marks = data.marks[student.id] ?? InternalMarks.empty(
                    subjectId: subjectId,
                    studentId: student.id,
                    teacherId: data.teacher.id,
                  );

                  // Auto-update attendance marks in the model if they are different
                  if (marks.attendanceMarks != attMarks) {
                    final updatedMarks = marks.copyWith(
                      attendanceMarks: attMarks.toDouble(),
                      totalMarks: marks.assignmentMarks + marks.testMarks + attMarks,
                    );

                    // Use a post-frame callback to avoid building during a build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateMarks(ref, updatedMarks, false); // Silently update attendance
                    });
                  }

                  return _StudentMarkTile(
                    student: student,
                    marks: marks,
                    attendancePct: attPct,
                    onSave: (assignment, test) {
                      _updateMarks(
                        ref,
                        marks.copyWith(
                          assignmentMarks: assignment,
                          testMarks: test,
                          totalMarks: assignment + test + attMarks,
                          updatedAt: DateTime.now(),
                        ),
                        true, // Show snackbar
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateMarks(WidgetRef ref, InternalMarks marks, bool showSnackbar) async {
    // 1. Save the new marks to the database
    await ref.read(internalMarksRepoProvider).updateMarks(marks);

    // 2. Invalidate the provider to force it to re-fetch from the database
    ref.invalidate(subjectGradingProvider(marks.subjectId));

    // 3. Show feedback if it was an explicit save
    if (showSnackbar && ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        SnackBar(
          content: Text('Saved marks for ${marks.studentId}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _StudentMarkTile extends StatefulWidget {
  final UserAccount student;
  final InternalMarks marks;
  final int attendancePct;
  final Function(double assignment, double test) onSave;

  const _StudentMarkTile({
    required this.student,
    required this.marks,
    required this.attendancePct,
    required this.onSave,
  });

  @override
  State<_StudentMarkTile> createState() => _StudentMarkTileState();
}

class _StudentMarkTileState extends State<_StudentMarkTile> {
  final TextEditingController _assignmentCtrl = TextEditingController();
  final TextEditingController _testCtrl = TextEditingController();

  // --- FIX: Removed FocusNode listeners for auto-save ---

  @override
  void initState() {
    super.initState();
    _assignmentCtrl.text = widget.marks.assignmentMarks.toStringAsFixed(0);
    _testCtrl.text = widget.marks.testMarks.toStringAsFixed(0);
  }

  void _saveMarks() {
    // Unfocus to hide keyboard
    FocusScope.of(context).unfocus();

    final assignment = double.tryParse(_assignmentCtrl.text) ?? 0.0;
    final test = double.tryParse(_testCtrl.text) ?? 0.0;

    // Clamp values
    final clampedAssignment = assignment.clamp(0.0, 12.0);
    final clampedTest = test.clamp(0.0, 12.0);

    // Update text fields to show clamped values
    _assignmentCtrl.text = clampedAssignment.toStringAsFixed(0);
    _testCtrl.text = clampedTest.toStringAsFixed(0);

    widget.onSave(clampedAssignment, clampedTest);
  }

  @override
  void dispose() {
    _assignmentCtrl.dispose();
    _testCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StudentMarkTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always update text if the underlying data changes
    _assignmentCtrl.text = widget.marks.assignmentMarks.toStringAsFixed(0);
    _testCtrl.text = widget.marks.testMarks.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: CircleAvatar(
        child: Text(widget.student.name.isNotEmpty ? widget.student.name[0] : '?'),
      ),
      title: Text(widget.student.name),
      subtitle: Text('CR: ${widget.student.collegeRollNo ?? 'N/A'}'),
      trailing: Text(
        '${widget.marks.totalMarks.toStringAsFixed(0)} / 30',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          // --- FIX: Use a Wrap to prevent overflow ---
          child: Wrap(
            runSpacing: 16,
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _MarkInput(
                label: 'Assignment',
                max: 12,
                controller: _assignmentCtrl,
              ),
              _MarkInput(
                label: 'Test/Ppt',
                max: 12,
                controller: _testCtrl,
              ),
              _MarkInput(
                label: 'Attendance',
                max: 6,
                value: '${widget.marks.attendanceMarks.toStringAsFixed(0)} (${widget.attendancePct}%)',
                isReadOnly: true,
              ),
              // --- FIX: Add an explicit Save button ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Marks'),
                  onPressed: _saveMarks,
                ),
              ),
            ],
          ),
          // --- End of Fix ---
        ),
      ],
    );
  }
}

class _MarkInput extends StatelessWidget {
  final String label;
  final int max;
  final String? value;
  final bool isReadOnly;
  final TextEditingController? controller;

  const _MarkInput({
    required this.label,
    required this.max,
    this.value,
    this.isReadOnly = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // --- FIX: Use flexible width for Wrap ---
    return SizedBox(
      width: 100,
      child: isReadOnly
          ? TextField(
        controller: TextEditingController(text: value),
        readOnly: true,
        decoration: InputDecoration(
          labelText: '$label (/$max)',
          disabledBorder: const UnderlineInputBorder(),
        ),
      )
          : TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '$label (/$max)',
        ),
      ),
    );
    // --- End of Fix ---
  }
}