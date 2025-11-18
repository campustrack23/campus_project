// lib/features/admin/attendance_overrides_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
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
  ConsumerState<AttendanceOverridesPage> createState() => _AttendanceOverridesPageState();
}

class _AttendanceOverridesPageState extends ConsumerState<AttendanceOverridesPage> {
  DateTime _date = DateTime.now();
  String? _subjectId;
  int? _year; // null = all
  final Map<String, AttendanceStatus> _edited = {};
  String _query = '';

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
          IconButton(onPressed: () => ref.invalidate(adminAttendanceProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // --- FIX: Use the new error widget ---
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminAttendanceProvider),
        ),
        // --- End of Fix ---
        data: (data) {
          final allRecords = data['records'] as List<AttendanceRecord>;
          final allSubjects = data['subjects'] as List<Subject>;
          final allStudents = data['students'] as List<UserAccount>;

          final subjectsMap = {for (final s in allSubjects) s.id: s};
          final studentsMap = {for (final s in allStudents) s.id: s};

          final filtered = allRecords.where((r) {
            final sameDay = r.date.year == _date.year && r.date.month == _date.month && r.date.day == _date.day;
            if (!sameDay) return false;
            if (_subjectId != null && r.subjectId != _subjectId) return false;

            final stu = studentsMap[r.studentId];
            if (stu == null) return false;
            if (_year != null && (stu.year == null || stu.year != _year)) return false;

            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final nameMatch = stu.name.toLowerCase().contains(q);
              final crMatch = (stu.collegeRollNo ?? '').toLowerCase().contains(q);
              if (!nameMatch && !crMatch) return false;
            }
            return true;
          }).toList()
            ..sort((a, b) {
              final sa = subjectsMap[a.subjectId]?.name ?? a.subjectId;
              final sb = subjectsMap[b.subjectId]?.name ?? b.subjectId;
              final byS = sa.compareTo(sb);
              if (byS != 0) return byS;
              return a.slot.compareTo(b.slot);
            });

          final dateStr = DateFormat('MMM d, yyyy').format(_date);
          final screenW = MediaQuery.of(context).size.width;
          final fieldWidth = screenW - 32;
          final subjectList = subjectsMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: _pickDate,
                      child: Text(dateStr),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: fieldWidth),
                      child: DropdownButtonFormField<String?>(
                        initialValue: _subjectId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All subjects', overflow: TextOverflow.ellipsis)),
                          ...subjectList.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _subjectId = v),
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                    ),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        labelText: 'Search by student name or CR',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(padding: EdgeInsets.only(right: 8), child: Text('Year:', style: TextStyle(fontWeight: FontWeight.w600))),
                        ChoiceChip(label: const Text('All'), selected: _year == null, onSelected: (_) => setState(() => _year = null)),
                        const SizedBox(width: 6),
                        for (int y in [1, 2, 3, 4]) ...[
                          ChoiceChip(label: Text('$y'), selected: _year == y, onSelected: (_) => setState(() => _year = y)),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    FilledButton(
                      onPressed: _edited.isEmpty ? null : () => _save(allRecords),
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No records for selected filters'))
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final subj = subjectsMap[r.subjectId];
                    final stu = studentsMap[r.studentId];
                    final status = _edited[r.id] ?? r.status;
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('Student: ${stu?.name ?? r.studentId}'
                          '${(stu?.collegeRollNo ?? '').isNotEmpty ? '  •  CR ${stu!.collegeRollNo}' : ''}'),
                      subtitle: Text('${subj?.name ?? r.subjectId} • ${r.slot}'),
                      trailing: DropdownButton<AttendanceStatus>(
                        value: status,
                        onChanged: (v) => setState(() => _edited[r.id] = v!),
                        items: AttendanceStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
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
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2031),
      initialDate: _date,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save(List<AttendanceRecord> allRecords) async {
    final attRepo = ref.read(attendanceRepoProvider);
    final allRecordsMap = {for (final r in allRecords) r.id: r};

    for (final entry in _edited.entries) {
      final rec = allRecordsMap[entry.key];
      if (rec == null) continue;
      await attRepo.mark(
        subjectId: rec.subjectId,
        studentId: rec.studentId,
        date: rec.date,
        slot: rec.slot,
        status: entry.value,
        markedByTeacherId: rec.markedByTeacherId, // Retain original marker
      );
    }
    setState(() => _edited.clear());
    ref.invalidate(adminAttendanceProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overrides saved')));
  }
}