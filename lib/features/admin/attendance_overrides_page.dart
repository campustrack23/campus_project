import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Now 'allRecords()' is valid
  final records = await attRepo.allRecords();
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
  DateTime _date = DateTime.now();
  final Map<String, AttendanceStatus> _edited = {};

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(adminAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Overrides'),
        actions: [
          if (_edited.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: () => _saveChanges(context),
            ),
          const SizedBox(width: 8),
          const ProfileAvatarAction(),
        ],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.refresh(adminAttendanceProvider)
        ),
        data: (data) {
          final records = data['records'] as List<AttendanceRecord>;
          final subjects = data['subjects'] as List<Subject>;
          final students = data['students'] as List<UserAccount>;

          // Filter records by selected date
          final dayRecords = records.where((r) {
            final rLocal = r.date.toLocal();
            return rLocal.year == _date.year &&
                rLocal.month == _date.month &&
                rLocal.day == _date.day;
          }).toList();

          return Column(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Change Date'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: dayRecords.isEmpty
                    ? const Center(child: Text('No records found for this date.'))
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = dayRecords[i];
                    final student = students.firstWhere(
                            (s) => s.id == r.studentId,
                        orElse: () => _unknownUser);
                    final subject = subjects.firstWhere(
                            (s) => s.id == r.subjectId,
                        orElse: () => _unknownSubject);

                    final currentStatus = _edited[r.id] ?? r.status;

                    return ListTile(
                      title: Text(student.name),
                      subtitle: Text('${subject.name} • ${r.slot}'),
                      trailing: DropdownButton<AttendanceStatus>(
                        value: currentStatus,
                        underline: Container(),
                        items: AttendanceStatus.values.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase(),
                              style: TextStyle(
                                  color: _statusColor(s),
                                  fontWeight: FontWeight.bold)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _edited[r.id] = val);
                          }
                        },
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveChanges(BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();

    _edited.forEach((recordId, newStatus) {
      final ref = FirebaseFirestore.instance.collection('attendance').doc(recordId);
      batch.update(ref, {
        'status': newStatus.name,
        'markedByTeacherId': 'ADMIN_OVERRIDE',
        'markedAt': Timestamp.now(),
      });
    });

    try {
      await batch.commit();
      setState(() => _edited.clear());
      ref.invalidate(adminAttendanceProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Successfully')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present: return Colors.green;
      case AttendanceStatus.absent: return Colors.red;
      case AttendanceStatus.late: return Colors.orange;
      case AttendanceStatus.excused: return Colors.blue;
    }
  }

  // Helper objects for unknown references
  // FIXED: Removed 'const' keyword because DateTime.fromMillisecondsSinceEpoch is not const
  final _unknownUser = UserAccount(
      id: '?',
      role: UserRole.student,
      name: 'Unknown',
      email: '',
      phone: '',
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0)
  );

  final _unknownSubject = const Subject(
      id: '?',
      code: '?',
      name: 'Unknown',
      department: '',
      semester: '',
      section: '',
      teacherId: '');
}