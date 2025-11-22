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
import '../../main.dart';

final adminAttendanceProvider = FutureProvider.autoDispose((ref) async {
  final attRepo = ref.watch(attendanceRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);
  final authRepo = ref.watch(authRepoProvider);

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
  ConsumerState<AttendanceOverridesPage> createState() =>
      _AttendanceOverridesPageState();
}

class _AttendanceOverridesPageState
    extends ConsumerState<AttendanceOverridesPage> {
  DateTime _date = DateTime.now();
  String? _subjectId;
  int? _year;
  final Map<String, AttendanceStatus> _edited = {};
  String _query = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(adminAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Attendance Overrides'),
        actions: [
          const ProfileAvatarAction(),
          IconButton(
            onPressed: () => ref.invalidate(adminAttendanceProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
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
          final allSubjects = data['subjects'] as List<Subject>;
          final allStudents = data['students'] as List<UserAccount>;

          final subjectsMap = {for (final s in allSubjects) s.id: s};
          final studentsMap = {for (final s in allStudents) s.id: s};

          final filtered = allRecords.where((r) {
            final sameDay =
                r.date.year == _date.year &&
                    r.date.month == _date.month &&
                    r.date.day == _date.day;
            if (!sameDay) return false;

            if (_subjectId != null && r.subjectId != _subjectId) return false;

            final stu = studentsMap[r.studentId];
            if (stu == null) return false;

            if (_year != null && (stu.year == null || stu.year != _year)) {
              return false;
            }

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final nameMatch = stu.name.toLowerCase().contains(q);
              final crMatch =
              (stu.collegeRollNo ?? '').toLowerCase().contains(q);
              if (!nameMatch && !crMatch) return false;
            }

            return true;
          }).toList()
            ..sort((a, b) {
              final sa = subjectsMap[a.subjectId]?.name ?? a.subjectId;
              final sb = subjectsMap[b.subjectId]?.name ?? b.subjectId;
              final bySubject = sa.compareTo(sb);
              if (bySubject != 0) return bySubject;
              return a.slot.compareTo(b.slot);
            });

          final dateStr = DateFormat('MMM d, yyyy').format(_date);

          final screenW = MediaQuery.of(context).size.width;
          final fieldWidth = screenW > 600 ? 400.0 : screenW - 32;

          final subjectList = subjectsMap.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Date Button (FIXED)
                    FilledButton.tonalIcon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(dateStr),
                    ),

                    // Subject Dropdown (FIXED initialValue)
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _subjectId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All subjects',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...subjectList.map(
                                (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _subjectId = v),
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    // Search Field
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          labelText: 'Search by student name or CR',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                              : null,
                        ),
                      ),
                    ),

                    // Year
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            'Year:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _year == null,
                          onSelected: (_) => setState(() => _year = null),
                        ),
                        const SizedBox(width: 6),
                        for (int y in [1, 2, 3, 4]) ...[
                          ChoiceChip(
                            label: Text('$y'),
                            selected: _year == y,
                            onSelected: (_) => setState(() => _year = y),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),

                    FilledButton(
                      onPressed:
                      _edited.isEmpty ? null : () => _save(allRecords),
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 0),

              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No records for selected filters'),
                  ),
                )
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final subj = subjectsMap[r.subjectId];
                    final stu = studentsMap[r.studentId];

                    final status = _edited[r.id] ?? r.status;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (stu?.name.isNotEmpty ?? false)
                              ? stu!.name.characters.first.toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(
                        stu?.name ?? r.studentId,
                        style:
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((stu?.collegeRollNo ?? '').isNotEmpty)
                            Text('CR ${stu!.collegeRollNo}'),
                          Text(
                            '${subj?.name ?? r.subjectId} • ${r.slot}',
                          ),
                        ],
                      ),
                      trailing: DropdownButton<AttendanceStatus>(
                        value: status,
                        underline: const SizedBox(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _edited[r.id] = v);
                        },
                        items: AttendanceStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.name.toUpperCase(),
                              style: TextStyle(
                                color:
                                s == AttendanceStatus.present
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                        )
                            .toList(),
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
      lastDate: DateTime(2031),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save(List<AttendanceRecord> allRecords) async {
    final attRepo = ref.read(attendanceRepoProvider);
    final allRecordsMap = {for (final r in allRecords) r.id: r};

    try {
      await Future.wait(
        _edited.entries.map((entry) async {
          final rec = allRecordsMap[entry.key];
          if (rec != null) {
            await attRepo.mark(
              subjectId: rec.subjectId,
              studentId: rec.studentId,
              date: rec.date,
              slot: rec.slot,
              status: entry.value,
              markedByTeacherId: rec.markedByTeacherId,
            );
          }
        }),
      );

      setState(() => _edited.clear());
      ref.invalidate(adminAttendanceProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Overrides saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
