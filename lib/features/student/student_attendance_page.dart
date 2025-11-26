// lib/features/student/student_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/attendance.dart';
import '../../core/models/user.dart';
import '../../core/models/subject.dart';
import '../../main.dart';

class StudentSubjectStats {
  final String subjectId;
  final String name;
  final int total;
  final int present;
  final int pct;
  final Color color;

  StudentSubjectStats({
    required this.subjectId,
    required this.name,
    required this.total,
    required this.present,
    required this.pct,
    required this.color,
  });
}

class _AttendanceData {
  final List<AttendanceRecord> sortedRecords;
  final List<StudentSubjectStats> subjectStats;
  _AttendanceData({required this.sortedRecords, required this.subjectStats});
}


final attendanceDataProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in');

  final attRepo = ref.read(attendanceRepoProvider);
  final ttRepo = ref.read(timetableRepoProvider);

  final records = await attRepo.forStudent(user.id);
  final subjectsList = await ttRepo.allSubjects();
  final subjects = {for (final s in subjectsList) s.id: s};

  int startMinutes(String slot) {
    try {
      final hh = int.parse(slot.substring(0, 2));
      final mm = int.parse(slot.substring(3, 5));
      return hh * 60 + mm;
    } catch (_) {
      return 0;
    }
  }

  Color chipColor(int pct) {
    if (pct < 75) return Colors.red.withAlpha((0.85 * 255).toInt());
    if (pct < 85) return Colors.orange.withAlpha((0.85 * 255).toInt());
    return Colors.green.withAlpha((0.85 * 255).toInt());
  }

  final sortedRecords = [...records]..sort((a, b) {
    final d = b.date.compareTo(a.date);
    return d != 0 ? d : startMinutes(a.slot).compareTo(startMinutes(b.slot));
  });

  final Map<String, List<AttendanceRecord>> bySubj = {};
  for (final r in records) {
    (bySubj[r.subjectId] ??= []).add(r);
  }

  final List<StudentSubjectStats> subjectStats = [];
  for (final entry in bySubj.entries) {
    final total = entry.value.length;

    // FIX: Count 'Late' as Present for percentage calculation
    final present = entry.value
        .where((r) =>
    r.status == AttendanceStatus.present ||
        r.status == AttendanceStatus.excused ||
        r.status == AttendanceStatus.late)
        .length;

    final pct = total == 0 ? 0 : ((present * 100) / total).round();
    final subjName = subjects[entry.key]?.name ?? entry.key;

    subjectStats.add(StudentSubjectStats(
      subjectId: entry.key,
      name: subjName,
      total: total,
      present: present,
      pct: pct,
      color: chipColor(pct),
    ));
  }
  subjectStats.sort((a, b) => a.name.compareTo(b.name));

  return _AttendanceData(
    sortedRecords: sortedRecords,
    subjectStats: subjectStats,
  );
});

class StudentAttendancePage extends ConsumerStatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  ConsumerState<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends ConsumerState<StudentAttendancePage> {
  String? _selectedSubjectId;

  Future<void> _refresh() async => ref.invalidate(attendanceDataProvider);

  @override
  Widget build(BuildContext context) {
    final dFmt = DateFormat('MMM d, yyyy');
    final asyncData = ref.watch(attendanceDataProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('My Attendance'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(attendanceDataProvider),
        ),
        data: (data) {
          final subjectsList = (data as _AttendanceData).subjectStats;
          final allRecords = data.sortedRecords;
          final subjectsMap = {
            for (final s in subjectsList) s.subjectId: s.name
          };

          final filteredRecords = _selectedSubjectId == null
              ? allRecords
              : allRecords.where((r) => r.subjectId == _selectedSubjectId).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: allRecords.isEmpty
                ? const Center(child: Text('No attendance yet'))
                : Column(
              children: [
                SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedSubjectId = null),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.75 * 255).toInt()),
                            borderRadius: BorderRadius.circular(12),
                            border: _selectedSubjectId == null
                                ? Border.all(color: Colors.white, width: 1.2)
                                : null,
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              SizedBox(height: 4),
                              Text('All subjects', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                      ...subjectsList.map((stat) {
                        final selected = _selectedSubjectId == stat.subjectId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedSubjectId = selected ? null : stat.subjectId),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: stat.color,
                              borderRadius: BorderRadius.circular(12),
                              border: selected ? Border.all(color: Colors.white, width: 1.2) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stat.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('${stat.pct}% • ${stat.present}/${stat.total}', style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      final r = filteredRecords[i];
                      final subjName = subjectsMap[r.subjectId] ?? r.subjectId;
                      // Late is also "OK" for presence purposes, though maybe colored orange
                      final isPresent = r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused;
                      final isLate = r.status == AttendanceStatus.late;

                      return ListTile(
                        leading: Icon(
                          isPresent ? Icons.check_circle : (isLate ? Icons.watch_later : Icons.cancel),
                          color: isPresent ? Colors.green : (isLate ? Colors.orange : Colors.red),
                        ),
                        title: Text(subjName),
                        subtitle: Text('${dFmt.format(r.date.toLocal())}  ${r.slot}'),
                        trailing: Text(
                          r.status.name.toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isPresent ? Colors.green : (isLate ? Colors.orange : Colors.red)
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(),
                    itemCount: filteredRecords.length,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}