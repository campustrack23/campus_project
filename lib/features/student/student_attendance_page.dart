// lib/features/student/student_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/attendance.dart';
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

final attendanceDataProvider = FutureProvider.autoDispose<_AttendanceData>((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in');

  final attRepo = ref.watch(attendanceRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);

  // Parallel fetch
  final results = await Future.wait([
    attRepo.forStudent(user.id),
    ttRepo.allSubjects(),
  ]);

  final records = results[0] as List<AttendanceRecord>;
  final subjects = results[1] as List; // List<Subject>
  final subjectsMap = {for (var s in subjects) s.id: s.name};

  // Calculate stats per subject
  final Map<String, List<AttendanceRecord>> grouped = {};
  for (var r in records) {
    grouped.putIfAbsent(r.subjectId, () => []).add(r);
  }

  final List<StudentSubjectStats> stats = [];
  grouped.forEach((subId, recs) {
    final total = recs.length;
    // Present + Late + Excused count as attended
    final present = recs.where((r) =>
    r.status == AttendanceStatus.present ||
        r.status == AttendanceStatus.late ||
        r.status == AttendanceStatus.excused
    ).length;

    final pct = total == 0 ? 100 : ((present / total) * 100).round();

    Color color = Colors.green;
    if (pct < 75) {color = Colors.red;}
    else if (pct < 85) {color = Colors.orange;}

    stats.add(StudentSubjectStats(
      subjectId: subId,
      name: subjectsMap[subId] ?? 'Unknown Subject',
      total: total,
      present: present,
      pct: pct,
      color: color,
    ));
  });

  stats.sort((a, b) => a.name.compareTo(b.name));

  return _AttendanceData(sortedRecords: records, subjectStats: stats);
});

class StudentAttendancePage extends ConsumerWidget {
  const StudentAttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(attendanceDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.refresh(attendanceDataProvider),
        ),
        data: (data) {
          if (data.sortedRecords.isEmpty) {
            return const Center(child: Text('No attendance records found.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(attendanceDataProvider.future),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Summary Cards ---
                  Text('Subject Wise', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: data.subjectStats.length,
                    itemBuilder: (ctx, i) {
                      final stat = data.subjectStats[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stat.color.withOpacity(0.5), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              stat.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${stat.present}/${stat.total}', style: TextStyle(color: Colors.grey[600])),
                                Text('${stat.pct}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stat.color)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  Text('Recent History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // --- History List ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.sortedRecords.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = data.sortedRecords[i];
                      // Find subject name from stats or map
                      final subjName = data.subjectStats.firstWhere((s) => s.subjectId == r.subjectId, orElse: () => StudentSubjectStats(subjectId: '', name: 'Unknown', total: 0, present: 0, pct: 0, color: Colors.black)).name;

                      final isPresent = r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused;
                      final isLate = r.status == AttendanceStatus.late;
                      final color = isPresent ? Colors.green : (isLate ? Colors.orange : Colors.red);
                      final icon = isPresent ? Icons.check_circle : (isLate ? Icons.access_time_filled : Icons.cancel);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(icon, color: color),
                        title: Text(subjName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${DateFormat('MMM d').format(r.date)} • ${r.slot}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.status.name.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}