// lib/features/student/student_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../main.dart';
import '../../core/utils/time_formatter.dart';

// ===== DATA PROVIDER FOR THIS PAGE =====
final studentDashboardProvider = FutureProvider.autoDispose<StudentDashboardData>((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in.');

  final section = user.section ?? _StudentHomePageState._sectionForYear(user.year);

  final ttRepo = ref.watch(timetableRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);

  // Fetch all data in parallel
  final results = await Future.wait([
    ttRepo.forSection(section),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
    attRepo.forStudent(user.id),
  ]);

  return StudentDashboardData(
    student: user,
    section: section,
    timetableEntries: results[0] as List<TimetableEntry>,
    allSubjects: results[1] as List<Subject>,
    allUsers: results[2] as List<UserAccount>,
    attendanceRecords: results[3] as List<AttendanceRecord>,
  );
});

// A helper class to hold all the data
class StudentDashboardData {
  final UserAccount student;
  final String section;
  final List<TimetableEntry> timetableEntries;
  final List<Subject> allSubjects;
  final List<UserAccount> allUsers;
  final List<AttendanceRecord> attendanceRecords;
  StudentDashboardData({
    required this.student,
    required this.section,
    required this.timetableEntries,
    required this.allSubjects,
    required this.allUsers,
    required this.attendanceRecords,
  });
}


class StudentHomePage extends ConsumerStatefulWidget {
  const StudentHomePage({super.key});

  @override
  ConsumerState<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends ConsumerState<StudentHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(studentDashboardProvider);
    await ref.read(studentDashboardProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(studentDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Student Dashboard'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Scan Attendance QR',
        onPressed: () => context.push('/student/scan-qr'),
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // --- FIX: Use the new error widget ---
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(studentDashboardProvider),
        ),
        // --- End of Fix ---
        data: (data) {
          final student = data.student;
          final section = data.section;
          final entriesAll = data.timetableEntries;
          final subjects = {for (final s in data.allSubjects) s.id: s};
          final teacherMap = { for (final u in data.allUsers.where((x) => x.role == UserRole.teacher)) u.id: u.name };

          final todayKey = _dayStr(DateTime.now().weekday);
          final todays = entriesAll.where((e) => e.dayOfWeek == todayKey).toList()
            ..sort((a, b) => _toMin(a.startTime).compareTo(_toMin(b.startTime)));
          final nextClass = _findNextOrOngoing(todays);

          final records = data.attendanceRecords;
          final total = records.length;
          final present = records.where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused).length;
          final pct = total == 0 ? 100 : ((present * 100) / total).round();

          final tiles = [
            _Tile('My Attendance', Icons.fact_check, '/student/attendance'),
            _Tile('My Timetable', Icons.calendar_today, '/student/timetable'),
            _Tile('Raise Query', Icons.help_center, '/student/raise-query'),
          ];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF2D232C),
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello, ${student.name.split(' ').first}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('Overall attendance: $pct% • Section $section',
                                    style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () => context.push('/notifications'),
                            icon: const Icon(Icons.notifications_outlined),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _NextClassBanner(
                    nextClass: nextClass,
                    todaysEmpty: todays.isEmpty,
                    subjects: subjects,
                    teacherMap: teacherMap,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: tiles.length > 2 ? 2 : tiles.length, // Handles 1, 2, or 3 items gracefully
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: tiles.length > 2 ? 1.2 : 1.5, // Make items wider if there are only 2
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (_, i) {
                      final t = tiles[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: InkWell(
                          onTap: () => context.push(t.path),
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(t.icon, size: 40, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Add padding to bottom to avoid FAB
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _sectionForYear(int? y) => switch (y) {
    1 => 'I-HE',
    2 => 'II-HE',
    3 => 'III-HE',
    _ => 'IV-HE',
  };

  String _dayStr(int weekday) {
    const m = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return m[weekday]!;
  }

  int _toMin(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

  _Upcoming? _findNextOrOngoing(List<TimetableEntry> todays) {
    if (todays.isEmpty) return null;
    final now = DateTime.now();
    DateTime todayAt(String hhmm) {
      final parts = hhmm.split(':');
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    for (final e in todays) {
      final start = todayAt(e.startTime);
      final end = todayAt(e.endTime);
      if (!now.isBefore(start) && now.isBefore(end)) {
        return _Upcoming(e, end.difference(now).inMinutes, isOngoing: true);
      }
      if (start.isAfter(now)) {
        return _Upcoming(e, start.difference(now).inMinutes, isOngoing: false);
      }
    }
    return null;
  }
}

class _Upcoming {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;
  _Upcoming(this.entry, this.minutesToStart, {required this.isOngoing});
}

class _NextClassBanner extends StatelessWidget {
  final _Upcoming? nextClass;
  final bool todaysEmpty;
  final Map<String, Subject> subjects;
  final Map<String, String> teacherMap;

  const _NextClassBanner({
    required this.nextClass,
    required this.todaysEmpty,
    required this.subjects,
    required this.teacherMap,
  });

  @override
  Widget build(BuildContext context) {
    if (todaysEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No classes scheduled today.'),
          subtitle: Text('Check the weekly timetable for your section.'),
        ),
      );
    }
    if (nextClass == null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: Icon(Icons.done_all),
          title: Text('All classes done for today.'),
          subtitle: Text('See tomorrow’s schedule in the timetable.'),
        ),
      );
    }

    final e = nextClass!.entry;
    final isOngoing = nextClass!.isOngoing;
    final minutesToStart = nextClass!.minutesToStart;
    final subjectName = subjects[e.subjectId]?.name ?? e.subjectId;
    final leadId = subjects[e.subjectId]?.teacherId;
    final ids = e.teacherIds.isNotEmpty ? e.teacherIds : [if (leadId != null && leadId.isNotEmpty) leadId];
    final tNames = ids.map((t) => teacherMap[t] ?? 'Teacher').join(' + ');
    final teacherText = tNames.isEmpty ? '' : ' • $tNames';
    final slotString = '${TimeFormatter.formatTime(e.startTime)} - ${TimeFormatter.formatTime(e.endTime)}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(
          isOngoing
              ? 'Ongoing • ends in $minutesToStart min'
              : 'Next class in $minutesToStart min',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$subjectName • $slotString • Room ${e.room}$teacherText'),
        trailing: FilledButton.tonal(
          onPressed: () => GoRouter.of(context).push('/student/timetable'),
          child: const Text('Timetable'),
        ),
      ),
    );
  }
}

class _Tile {
  final String title;
  final IconData icon;
  final String path;
  _Tile(this.title, this.icon, this.path);
}