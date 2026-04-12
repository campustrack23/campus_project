// lib/features/assignments/assignments_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/models/role.dart';
import '../../core/models/subject.dart';
import '../../main.dart';
import 'assignment_detail_page.dart';

// Provider to fetch subjects for the teacher dropdown
final teacherSubjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null || user.role != UserRole.teacher) return [];
  final allSubjects = await ref.watch(timetableRepoProvider).allSubjects();
  return allSubjects.where((s) => s.teacherId == user.id).toList();
});

final assignmentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) return [];

  final allAssignments = await ref.watch(apiServiceProvider).getAssignments();

  // 🔴 DEBUG TOOL: Prints to your terminal to see exact backend keys
  debugPrint('--- RAW ASSIGNMENTS FROM BACKEND ---');
  if (allAssignments.isNotEmpty) {
    debugPrint(allAssignments.first.toString());
  }

  // 🔴 FILTERING LOGIC: Ensure students only see their section's assignments
  if (user.role == UserRole.student) {
    return allAssignments.where((a) => a['section'] == user.section).toList();
  } else if (user.role == UserRole.teacher) {

    // 🟢 FOOLPROOF V2 FIX: Check both camelCase AND snake_case!
    final allSubjects = await ref.watch(timetableRepoProvider).allSubjects();
    final mySubjectIds = allSubjects
        .where((s) => s.teacherId == user.id)
        .map((s) => s.id)
        .toSet();

    return allAssignments.where((a) {
      // Safely grab whatever format the backend decided to use
      final String? dbTeacherId = (a['teacherId'] ?? a['teacher_id'] ?? a['createdBy'])?.toString();
      final String? dbSubjectId = (a['subjectId'] ?? a['subject_id'])?.toString();

      final isCreator = dbTeacherId == user.id;
      final isMySubject = mySubjectIds.contains(dbSubjectId);

      return isCreator || isMySubject;
    }).toList();
  }

  // Admin sees everything
  return allAssignments;
});

class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAssignments = ref.watch(assignmentsProvider);
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: asyncAssignments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (assignments) {
          if (assignments.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(assignmentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignments.length,
              itemBuilder: (ctx, i) {
                final assgn = assignments[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Navigate to Detail Page (Teams Style)
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AssignmentDetailPage(assignment: assgn),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.assignment_turned_in, color: Colors.indigo),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assgn['subjectName'] ?? 'Subject', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                Text(assgn['title'] ?? 'Assignment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: userAsync.maybeWhen(
        data: (user) {
          if (user != null && user.role == UserRole.teacher) {
            return FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateDialog(context, ref, user.id),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No assignments right now.', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
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

// --- Stateful Dialog for Teacher Creation ---
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

    return AlertDialog(
      title: const Text('New Assignment'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subject Dropdown
            subjectsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => const Text('Failed to load subjects'),
              data: (subjects) {
                if (subjects.isEmpty) return const Text('You have no assigned subjects.');
                return DropdownButtonFormField<Subject>(
                  decoration: const InputDecoration(labelText: 'Select Subject', border: OutlineInputBorder()),
                  initialValue: selectedSubject,
                  items: subjects.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.name} (${s.section})'),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedSubject = val),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: isLoading ? null : _submit,
          child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Assign'),
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
      await ref.read(apiServiceProvider).createAssignment({
        'title': titleCtrl.text,
        'description': descCtrl.text,
        'teacherId': widget.teacherId,
        'subjectId': selectedSubject!.id,
        'subjectName': selectedSubject!.name,
        'section': selectedSubject!.section,
        'dueDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      ref.invalidate(assignmentsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}