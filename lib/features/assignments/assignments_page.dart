// lib/features/assignments/assignments_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/models/role.dart';
import '../../core/models/subject.dart';
import '../../main.dart';
import 'assignment_detail_page.dart';

// -----------------------------------------------------------------------------
// PROVIDERS
// -----------------------------------------------------------------------------
final teacherSubjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null || user.role != UserRole.teacher) return [];

  final ttRepo = ref.watch(timetableRepoProvider);
  final allSubjects = await ttRepo.allSubjects();
  final allEntries = await ttRepo.allEntries();

  // Find subject IDs where this teacher is assigned in the timetable
  final myTimetableSubjectIds = allEntries
      .where((e) => e.teacherIds.contains(user.id))
      .map((e) => e.subjectId)
      .toSet();

  return allSubjects.where((s) => s.teacherId == user.id || myTimetableSubjectIds.contains(s.id)).toList();
});

final assignmentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) return [];

  final allAssignments = await ref.watch(apiServiceProvider).getAssignments();
  final ttRepo = ref.watch(timetableRepoProvider);
  final allSubjects = await ttRepo.allSubjects();

  // Helper to normalize strings (removes ALL spaces and makes uppercase)
  String normalizeStr(String? val) => (val ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

  // ---------------------------------------------------------
  // 🟢 FOOLPROOF STUDENT FILTERING
  // ---------------------------------------------------------
  if (user.role == UserRole.student) {
    final studentSection = normalizeStr(user.section);

    final mySubjectIds = allSubjects
        .where((s) => normalizeStr(s.section) == studentSection)
        .map((s) => s.id)
        .toSet();

    final allEntries = await ttRepo.allEntries();
    final myTimetableSubjectIds = allEntries
        .where((e) => normalizeStr(e.section) == studentSection)
        .map((e) => e.subjectId)
        .toSet();

    final validSubjectIds = mySubjectIds.union(myTimetableSubjectIds);

    return allAssignments.where((a) {
      // ✅ FIX: Check both 'section' and 'class_id'
      final rawSection = a['section'] ?? a['class_id'] ?? '';
      final dbSection = normalizeStr(rawSection.toString());

      // ✅ FIX: Check both 'subjectId' and 'subject_id'
      final dbSubjectId = (a['subjectId'] ?? a['subject_id'])?.toString();

      final matchSection = studentSection.isNotEmpty && dbSection == studentSection;
      final matchSubject = dbSubjectId != null && validSubjectIds.contains(dbSubjectId);

      return matchSection || matchSubject;
    }).toList();
  }

  // ---------------------------------------------------------
  // 🟢 FOOLPROOF TEACHER FILTERING
  // ---------------------------------------------------------
  else if (user.role == UserRole.teacher) {
    final allEntries = await ttRepo.allEntries();
    final myTimetableSubjectIds = allEntries.where((e) => e.teacherIds.contains(user.id)).map((e) => e.subjectId).toSet();

    final mySubjectIds = allSubjects
        .where((s) => s.teacherId == user.id || myTimetableSubjectIds.contains(s.id))
        .map((s) => s.id)
        .toSet();

    return allAssignments.where((a) {
      final dbTeacherId = (a['teacherId'] ?? a['teacher_id'] ?? a['createdBy'] ?? a['uploaded_by'])?.toString();
      final dbSubjectId = (a['subjectId'] ?? a['subject_id'])?.toString();

      final isCreator = dbTeacherId == user.id;
      final isMySubject = mySubjectIds.contains(dbSubjectId);

      return isCreator || isMySubject;
    }).toList();
  }

  // Admin sees everything
  return allAssignments;
});

// -----------------------------------------------------------------------------
// MAIN PAGE
// -----------------------------------------------------------------------------
class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAssignments = ref.watch(assignmentsProvider);
    final userAsync = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Coursework', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assignments', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Manage your pending coursework and submissions.', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: asyncAssignments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (assignments) {
                if (assignments.isEmpty) return _buildEmptyState(colorScheme);

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(assignmentsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: assignments.length,
                    itemBuilder: (ctx, i) {
                      final assgn = assignments[i];
                      // ✅ FIX: Read from both camelCase and snake_case
                      final displayTitle = assgn['title'] ?? 'Untitled Assignment';
                      final displaySubject = assgn['subjectName'] ?? assgn['subject_name'] ?? 'General Subject';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AssignmentDetailPage(assignment: assgn),
                              ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                                    child: Icon(Icons.assignment_rounded, color: colorScheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text(displaySubject, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: userAsync.maybeWhen(
        data: (user) {
          if (user != null && user.role == UserRole.teacher) {
            return FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref, user.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 80, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('No pending assignments found.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String teacherId) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateAssignmentDialog(teacherId: teacherId),
    );
  }
}

// -----------------------------------------------------------------------------
// DIALOG: CREATE ASSIGNMENT
// -----------------------------------------------------------------------------
class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  final String teacherId;
  const _CreateAssignmentDialog({required this.teacherId});

  @override
  ConsumerState<_CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends ConsumerState<_CreateAssignmentDialog> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  Subject? selectedSubject;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(teacherSubjectsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('New Assignment', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            subjectsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => const Text('Failed to load subjects'),
              data: (subjects) {
                if (subjects.isEmpty) {
                  return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text('You have no assigned subjects.', style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold)),
                );
                }
                return DropdownButtonFormField<Subject>(
                  decoration: InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  initialValue: selectedSubject,
                  items: subjects.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.name} (${s.section})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedSubject = val),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: 'Assignment Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
            ),
            const SizedBox(height: 16),
            TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(labelText: 'Instructions', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Assign Class'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (selectedSubject == null || titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);
    try {
      final dueDateStr = DateTime.now().add(const Duration(days: 7)).toIso8601String();

      // ✅ FIX: Send BOTH camelCase and snake_case to satisfy any backend
      await ref.read(apiServiceProvider).createAssignment({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'teacherId': widget.teacherId,
        'teacher_id': widget.teacherId,
        'uploaded_by': widget.teacherId,
        'subjectId': selectedSubject!.id,
        'subject_id': selectedSubject!.id,
        'subjectName': selectedSubject!.name,
        'subject_name': selectedSubject!.name,
        'section': selectedSubject!.section,
        'class_id': selectedSubject!.section,
        'dueDate': dueDateStr,
        'due_date': dueDateStr,
        'semester': int.tryParse(selectedSubject!.semester) ?? 0,
      });

      ref.invalidate(assignmentsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment Published Successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}