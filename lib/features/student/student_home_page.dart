// lib/features/student/student_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../main.dart';

// --- VIEW MODEL ---
class StudentDashboardVM {
  final UserAccount student;
  final String section;
  final int attendancePct;
  final UpcomingClass? nextClass;
  final List<TimetableEntry> allEntries; // For grid
  final Map<String, Subject> subjectsMap;
  final Map<String, String> teacherNamesMap;

  StudentDashboardVM({
    required this.student,
    required this.section,
    required this.attendancePct,
    required this.nextClass,
    required this.allEntries,
    required this.subjectsMap,
    required this.teacherNamesMap,
  });
}

class UpcomingClass {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;
  UpcomingClass(this.entry, this.minutesToStart, {required this.isOngoing});
}

// --- OPTIMIZED PROVIDER ---
final studentDashboardProvider = FutureProvider.autoDispose<StudentDashboardVM>((ref) async {
  // 1. Cache data for 5 minutes (KeepAlive)
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () => link.close());
  ref.onDispose(() => timer.cancel());

  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in.');

  // 2. Helper to determine section
  String sectionForYear(int? y) => switch (y) {
    1 => 'I-HE', 2 => 'II-HE', 3 => 'III-HE', _ => 'IV-HE',
  };
  final section = user.section ?? sectionForYear(user.year);

  final ttRepo = ref.watch(timetableRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);

  // 3. Parallel Fetch
  final results = await Future.wait([
    ttRepo.forSection(section),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
    attRepo.forStudent(user.id),
  ]);

  final entries = results[0] as List<TimetableEntry>;
  final subjects = results[1] as List<Subject>;
  final users = results[2] as List<UserAccount>;
  final records = results[3] as List<AttendanceRecord>;

  // 4. Data Processing (Off UI Thread)
  final subjectsMap = {for (final s in subjects) s.id: s};
  final teacherMap = {
    for (final u in users.where((x) => x.role == UserRole.teacher)) u.id: u.name
  };

  // Calculate Attendance %
  final total = records.length;
  final present = records.where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused).length;
  final pct = total == 0 ? 100 : ((present * 100) / total).round();

  // Calculate Next Class
  final now = DateTime.now();
  final todayKey = _dayStr(now.weekday);

  int toMin(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

  final todayEntries = entries.where((e) => e.dayOfWeek == todayKey).toList()
    ..sort((a, b) => toMin(a.startTime).compareTo(toMin(b.startTime)));

  UpcomingClass? nextClass;
  for (final e in todayEntries) {
    final start = _todayAt(e.startTime, now);
    final end = _todayAt(e.endTime, now);

    if (!now.isBefore(start) && now.isBefore(end)) {
      nextClass = UpcomingClass(e, end.difference(now).inMinutes, isOngoing: true);
      break;
    }
    if (start.isAfter(now)) {
      nextClass = UpcomingClass(e, start.difference(now).inMinutes, isOngoing: false);
      break;
    }
  }

  return StudentDashboardVM(
    student: user,
    section: section,
    attendancePct: pct,
    nextClass: nextClass,
    allEntries: entries,
    subjectsMap: subjectsMap,
    teacherNamesMap: teacherMap,
  );
});

// Helpers
String _dayStr(int w) => const {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'}[w] ?? 'Mon';
DateTime _todayAt(String hm, DateTime now) {
  final p = hm.split(':');
  return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
}

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(studentDashboardProvider),
        ),
        data: (vm) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(studentDashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                _WelcomeCard(user: vm.student, pct: vm.attendancePct, section: vm.section),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _NextClassBanner(
                    nextClass: vm.nextClass,
                    subjects: vm.subjectsMap,
                    teacherMap: vm.teacherNamesMap,
                  ),
                ),
                _QuickActionsGrid(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final UserAccount user;
  final int pct;
  final String section;
  const _WelcomeCard({required this.user, required this.pct, required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${user.name.split(' ').first}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Attendance: $pct% • Sec $section',
                      style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => GoRouter.of(context).push('/notifications'),
              icon: const Icon(Icons.notifications_outlined),
            )
          ],
        ),
      ),
    );
  }
}

class _NextClassBanner extends StatelessWidget {
  final UpcomingClass? nextClass;
  final Map<String, Subject> subjects;
  final Map<String, String> teacherMap;

  const _NextClassBanner({required this.nextClass, required this.subjects, required this.teacherMap});

  @override
  Widget build(BuildContext context) {
    if (nextClass == null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: Icon(Icons.done_all),
          title: Text('All classes done for today.'),
          subtitle: Text('Check the timetable for tomorrow.'),
        ),
      );
    }

    final e = nextClass!.entry;
    final subjectName = subjects[e.subjectId]?.name ?? e.subjectId;
    final leadId = subjects[e.subjectId]?.teacherId;
    final tIds = e.teacherIds.isNotEmpty ? e.teacherIds : [if(leadId != null) leadId];
    final tNames = tIds.map((t) => teacherMap[t] ?? 'Teacher').join(' + ');

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(
          nextClass!.isOngoing ? 'Ongoing • Ends in ${nextClass!.minutesToStart}m' : 'Next in ${nextClass!.minutesToStart}m',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$subjectName • Room ${e.room}\n${tNames.isEmpty ? '' : tNames}'),
        isThreeLine: tNames.isNotEmpty,
        trailing: FilledButton.tonal(
          onPressed: () => GoRouter.of(context).push('/student/timetable'),
          child: const Text('Timetable'),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiles = [
      (title: 'Attendance', icon: Icons.fact_check, path: '/student/attendance'),
      (title: 'Timetable', icon: Icons.calendar_today, path: '/student/timetable'),
      (title: 'Raise Query', icon: Icons.help_center, path: '/student/raise-query'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: tiles.length > 2 ? 2 : tiles.length,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => Card(
          clipBehavior: Clip.antiAlias,
          // FIX: Added this color property so white text shows up on purple background
          color: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => GoRouter.of(context).push(tiles[i].path),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tiles[i].icon, size: 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(tiles[i].title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}