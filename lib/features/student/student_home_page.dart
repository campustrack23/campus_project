import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../main.dart';

// -----------------------------------------------------------------------------
// VIEW MODELS
// -----------------------------------------------------------------------------

class StudentDashboardVM {
  final UserAccount student;
  final String section;
  final int attendancePct;
  final List<TimetableEntry> timetable;
  final Map<String, Subject> subjectsMap;

  StudentDashboardVM({
    required this.student,
    required this.section,
    required this.attendancePct,
    required this.timetable,
    required this.subjectsMap,
  });
}

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------

final studentDashboardProvider =
FutureProvider.autoDispose<StudentDashboardVM>((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);

  // 1. Current student
  final student = await authRepo.currentUser();
  if (student == null) throw Exception('Not logged in');

  final section = student.section ?? '';

  // 2. Fetch data in parallel
  final results = await Future.wait([
    ttRepo.allSubjects(),
    ttRepo.forSection(section),
    attRepo.forStudent(student.id),
  ]);

  final subjects = results[0] as List<Subject>;
  final timetable = results[1] as List<TimetableEntry>;
  final attendance = results[2] as List<AttendanceRecord>;

  // 3. Subject map
  final subjectMap = {for (final s in subjects) s.id: s};

  // 4. Attendance %
  final presentCount = attendance.where((r) =>
  r.status == AttendanceStatus.present ||
      r.status == AttendanceStatus.late ||
      r.status == AttendanceStatus.excused).length;

  final total = attendance.length;
  final pct = total == 0 ? 100 : ((presentCount / total) * 100).round();

  return StudentDashboardVM(
    student: student,
    section: section,
    attendancePct: pct,
    timetable: timetable,
    subjectsMap: subjectMap,
  );
});

// -----------------------------------------------------------------------------
// UI
// -----------------------------------------------------------------------------

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(studentDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [ProfileAvatarAction()],
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(studentDashboardProvider),
        ),
        data: (vm) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(studentDashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(vm: vm),
                const SizedBox(height: 24),
                _AttendanceCard(pct: vm.attendancePct),
                const SizedBox(height: 24),
                _QuickActions(vm: vm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADER
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final StudentDashboardVM vm;
  const _Header({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${vm.student.name.split(' ').first} 👋',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${vm.section} • Roll No: ${vm.student.collegeRollNo ?? "N/A"}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color:
            Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// ATTENDANCE CARD
// -----------------------------------------------------------------------------

class _AttendanceCard extends StatelessWidget {
  final int pct;
  const _AttendanceCard({required this.pct});

  @override
  Widget build(BuildContext context) {
    Color base = Colors.green;
    if (pct < 75) {
      base = Colors.red;
    } else if (pct < 85) {
      base = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base.withValues(alpha: 0.8),
            base,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Attendance',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Keep it up!',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12),
              ),
            ],
          ),
          Text(
            '$pct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// QUICK ACTIONS
// -----------------------------------------------------------------------------

class _QuickActions extends ConsumerWidget {
  final StudentDashboardVM vm;
  const _QuickActions({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      (title: 'Scan QR', icon: Icons.qr_code_scanner, path: '/student/scan-qr'),
      (title: 'Attendance', icon: Icons.fact_check_outlined, path: '/student/attendance'),
      (title: 'Timetable', icon: Icons.calendar_today, path: '/student/timetable'),
      (title: 'Raise Query', icon: Icons.help_center, path: '/student/raise-query'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (_, i) {
        final item = actions[i];

        return Card(
          color: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              if (item.path == '/student/scan-qr') {
                await context.push(item.path);
                ref.invalidate(studentDashboardProvider);
              } else {
                context.push(item.path);
              }
            },
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Icon(item.icon,
                    size: 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                if (item.path.contains('attendance'))
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                        Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${vm.attendancePct}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
