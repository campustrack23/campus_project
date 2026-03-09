// lib/features/admin/internal_marks_overrides_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/internal_marks.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/models/role.dart';
import '../../main.dart';

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------

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
    'marks': marks,
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
  String _query = '';
  final Map<String, InternalMarks> _edited = {};

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(adminMarksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks Overrides'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.refresh(adminMarksProvider),
        ),
        data: (data) {
          final marks = data['marks'] as List<InternalMarks>;
          final subjects = data['subjects'] as List<Subject>;
          final students = data['students'] as List<UserAccount>;

          // Filter
          final filtered = marks.where((m) {
            if (_query.isEmpty) return true;
            final s = students.firstWhere((u) => u.id == m.studentId,
                orElse: () => _unknownUser);
            return s.name.toLowerCase().contains(_query.toLowerCase()) ||
                (s.collegeRollNo ?? '').contains(_query);
          }).toList();

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by student name or roll no',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final original = filtered[index];
                    // Display edited version if exists
                    final current = _edited[original.id] ?? original;

                    final student = students.firstWhere(
                            (s) => s.id == current.studentId,
                        orElse: () => _unknownUser);
                    final subject = subjects.firstWhere(
                            (s) => s.id == current.subjectId,
                        orElse: () => _unknownSubject);

                    final hasChanges = _edited.containsKey(original.id);

                    return ExpansionTile(
                      leading: CircleAvatar(
                          child: Text(student.name.isNotEmpty
                              ? student.name[0]
                              : '?')),
                      title: Text(student.name),
                      subtitle: Text('${subject.name} • Total: ${current.totalMarks}'),
                      trailing: hasChanges
                          ? const Icon(Icons.edit, color: Colors.orange)
                          : null,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _EditField(
                                  label: 'Attd (6)',
                                  value: current.attendanceMarks,
                                  max: 6,
                                  onChanged: (v) {
                                    setState(() {
                                      _edited[current.id] =
                                          current.copyWith(attendanceMarks: v);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _EditField(
                                  label: 'Assign (12)',
                                  value: current.assignmentMarks,
                                  max: 12,
                                  onChanged: (v) {
                                    setState(() {
                                      _edited[current.id] =
                                          current.copyWith(assignmentMarks: v);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _EditField(
                                  label: 'Test (12)',
                                  value: current.testMarks,
                                  max: 12,
                                  onChanged: (v) {
                                    setState(() {
                                      _edited[current.id] =
                                          current.copyWith(testMarks: v);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_edited.isNotEmpty)
                _SaveChangesBar(
                  count: _edited.length,
                  onCancel: () => setState(() => _edited.clear()),
                  onSave: () => _saveAll(context),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAll(BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();
    ref.read(internalMarksRepoProvider); // Access mainly for logic if needed, but here doing batch manually for speed

    for (final mark in _edited.values) {
      // Recalc total before saving
      final total = mark.attendanceMarks + mark.assignmentMarks + mark.testMarks;
      final toSave = mark.copyWith(totalMarks: total);

      final ref = FirebaseFirestore.instance.collection('internal_marks').doc(toSave.id);
      batch.set(ref, toSave.toMap(), SetOptions(merge: true));
    }

    try {
      await batch.commit();
      setState(() => _edited.clear());
      ref.invalidate(adminMarksProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All changes saved!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  // FIXED: Removed passwordHash and const
  final _unknownUser = UserAccount(
    id: '?',
    role: UserRole.student,
    name: 'Unknown Student',
    email: '',
    phone: '',
    isActive: true,
    createdAt: DateTime.now(),
  );

  final _unknownSubject = const Subject(
    id: '?',
    code: '?',
    name: 'Unknown Subject',
    department: '',
    semester: '',
    section: '',
    teacherId: '',
  );
}

class _EditField extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _EditField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        final d = double.tryParse(v) ?? 0.0;
        if (d <= max) {
          onChanged(d);
        }
      },
    );
  }
}

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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$count unsaved changes',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              FilledButton(onPressed: onSave, child: const Text('Save All')),
            ],
          ),
        ],
      ),
    );
  }
}