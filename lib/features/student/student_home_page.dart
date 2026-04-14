// lib/features/student/student_home_page.dart
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

final studentDashboardProvider = FutureProvider.autoDispose<StudentDashboardVM>((ref) async {
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
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [ProfileAvatarAction()],
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(studentDashboardProvider),
        ),
        data: (vm) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(studentDashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(vm: vm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ModernAttendanceCard(pct: vm.attendancePct),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickActions(vm: vm),
                ),
                const SizedBox(height: 40),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${vm.student.name.split(' ').first} 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vm.section,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Roll No: ${vm.student.collegeRollNo ?? "N/A"}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MODERN ATTENDANCE CARD
// -----------------------------------------------------------------------------

class _ModernAttendanceCard extends StatelessWidget {
  final int pct;
  const _ModernAttendanceCard({required this.pct});

  @override
  Widget build(BuildContext context) {
    // Dynamic styling based on health
    List<Color> gradientColors;
    String statusText;
    IconData statusIcon;

    if (pct >= 85) {
      gradientColors = const [Color(0xFF0D9488), Color(0xFF059669)]; // Teal/Green
      statusText = 'Excellent standing';
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (pct >= 75) {
      gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B)]; // Orange/Amber
      statusText = 'Requires attention';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      gradientColors = const [Color(0xFFE11D48), Color(0xFFDC2626)]; // Rose/Red
      statusText = 'Critical shortage';
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background subtle icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.analytics_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          statusText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Overall Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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
      _ActionData(
        title: 'Scan QR',
        icon: Icons.qr_code_scanner_rounded,
        path: '/student/scan-qr',
        themeColor: Colors.blue,
      ),
      _ActionData(
        title: 'Attendance',
        icon: Icons.fact_check_rounded,
        path: '/student/attendance',
        themeColor: Colors.teal,
        badgeText: '${vm.attendancePct}%',
      ),
      _ActionData(
        title: 'Timetable',
        icon: Icons.calendar_month_rounded,
        path: '/student/timetable',
        themeColor: Colors.purple,
      ),
      _ActionData(
        title: 'Raise Query',
        icon: Icons.support_agent_rounded,
        path: '/student/raise-query',
        themeColor: Colors.orange,
      ),
    ];

    // Using a responsive GridView to ensure cards aren't overly stretched
    return LayoutBuilder(
        builder: (context, constraints) {
          // Decide column count based on screen width
          int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 3 : 2);

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Keeps the aspect ratio slightly rectangular, stopping vertical stretching on web
              childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.1,
            ),
            itemBuilder: (_, i) {
              return _ModernActionCard(
                data: actions[i],
                onTap: () async {
                  if (actions[i].path == '/student/scan-qr') {
                    await context.push(actions[i].path);
                    ref.invalidate(studentDashboardProvider);
                  } else {
                    context.push(actions[i].path);
                  }
                },
              );
            },
          );
        }
    );
  }
}

class _ActionData {
  final String title;
  final IconData icon;
  final String path;
  final MaterialColor themeColor;
  final String? badgeText;

  _ActionData({
    required this.title,
    required this.icon,
    required this.path,
    required this.themeColor,
    this.badgeText,
  });
}

class _ModernActionCard extends StatelessWidget {
  final _ActionData data;
  final VoidCallback onTap;

  const _ModernActionCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            // FIXED: Much stronger, more visible border
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
            // FIXED: Slightly stronger shadow
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? data.themeColor.shade900.withValues(alpha: 0.5)
                            : data.themeColor.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        data.icon,
                        color: isDark ? data.themeColor.shade200 : data.themeColor.shade700,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Optional Badge (used for attendance %)
              if (data.badgeText != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data.themeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}