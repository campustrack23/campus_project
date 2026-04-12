// lib/features/admin/attendance_overrides_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/attendance.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/models/role.dart';
import '../../main.dart';

final adminAttendanceProvider = FutureProvider.autoDispose((ref) async {
  final attRepo = ref.watch(attendanceRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);
  final authRepo = ref.watch(authRepoProvider);

  final records = await attRepo.allRecords(limit: 500); // Limit read size
  final subjects = await ttRepo.allSubjects();
  final students = await authRepo.allStudents();

  return {
    'records': records,
    'subjects': subjects,
    'students': students,
  };
});

class AttendanceOverridesPage extends ConsumerStatefulWidget {
  const AttendanceOverridesPage({super.key});

  @override
  ConsumerState<AttendanceOverridesPage> createState() => _AttendanceOverridesPageState();
}

class _AttendanceOverridesPageState extends ConsumerState<AttendanceOverridesPage> {
  final Map<String, AttendanceStatus> _edited = {};
  String _searchQuery = '';
  bool _isSaving = false;

  final UserAccount _unknownUser = UserAccount(
    id: '?',
    role: UserRole.student,
    name: 'Unknown Student',
    phone: '',
    isActive: false,
    createdAt: DateTime.now(), // Safe initialisation
  );

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(adminAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Overrides'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminAttendanceProvider),
        ),
        data: (data) {
          final allRecords = data['records'] as List<AttendanceRecord>;
          final subjects = data['subjects'] as List<Subject>;
          final students = data['students'] as List<UserAccount>;

          final filtered = allRecords.where((r) {
            if (_searchQuery.isEmpty) return true;
            final st = students.firstWhere((s) => s.id == r.studentId, orElse: () => _unknownUser);
            final matchName = st.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchRoll = (st.collegeRollNo ?? '').contains(_searchQuery);
            return matchName || matchRoll;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Student Name / Roll No',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (_edited.isNotEmpty)
                Container(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_edited.length} unsaved change(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isSaving ? null : () => setState(() => _edited.clear()),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: _isSaving ? null : () => _saveChanges(ref),
                            child: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Apply'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final r = filtered[i];
                    final st = students.firstWhere((s) => s.id == r.studentId, orElse: () => _unknownUser);
                    final sub = subjects.firstWhere((s) => s.id == r.subjectId,
                        orElse: () => const Subject(
                            id: '', code: '?', name: 'Unknown',
                            department: '', semester: '', section: '', teacherId: ''));

                    final currentStatus = _edited[r.id] ?? r.status;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${st.name} (${st.collegeRollNo ?? 'N/A'})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${sub.name} • ${DateFormat('MMM d, yyyy').format(r.date)} • ${r.slot}',
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            SegmentedButton<AttendanceStatus>(
                              segments: const [
                                ButtonSegment(value: AttendanceStatus.present, label: Text('P')),
                                ButtonSegment(value: AttendanceStatus.absent, label: Text('A')),
                                ButtonSegment(value: AttendanceStatus.late, label: Text('L')),
                                ButtonSegment(value: AttendanceStatus.excused, label: Text('E')),
                              ],
                              selected: {currentStatus},
                              onSelectionChanged: (val) {
                                setState(() {
                                  if (val.first == r.status) {
                                    _edited.remove(r.id);
                                  } else {
                                    _edited[r.id] = val.first;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _saveChanges(WidgetRef ref) async {
    if (_edited.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final user = await ref.read(authRepoProvider).currentUser();
      if (user == null || !user.role.isAdmin) throw Exception('Unauthorized');

      await ref.read(attendanceRepoProvider).batchUpdateStatus(_edited, user.id);

      if (mounted) {
        setState(() {
          _edited.clear();
          _isSaving = false;
        });
        ref.invalidate(adminAttendanceProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overrides Saved Successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}