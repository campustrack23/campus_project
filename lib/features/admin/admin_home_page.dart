// lib/features/admin/admin_home_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/query_ticket.dart';

class AdminDashboardVM {
  final int totalUsers;
  final int totalStudents;
  final int totalTeachers;
  final int attendanceToday;
  final int openQueries;

  AdminDashboardVM({
    required this.totalUsers,
    required this.totalStudents,
    required this.totalTeachers,
    required this.attendanceToday,
    required this.openQueries,
  });
}

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardVM>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () => link.close());
  ref.onDispose(timer.cancel);

  final db = FirebaseFirestore.instance;

  // Create timestamp boundaries for "Today"
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  // PERFORMANCE FIX: Use Server-Side Aggregation (count) instead of downloading collections
  final results = await Future.wait([
    db.collection('users').count().get(),
    db.collection('users').where('role', isEqualTo: UserRole.student.key).count().get(),
    db.collection('users').where('role', isEqualTo: UserRole.teacher.key).count().get(),
    db.collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .count().get(),
    db.collection('queries')
        .where('status', whereIn: [QueryStatus.open.name, QueryStatus.inProgress.name])
        .count().get(),
  ]);

  return AdminDashboardVM(
    totalUsers: results[0].count ?? 0,
    totalStudents: results[1].count ?? 0,
    totalTeachers: results[2].count ?? 0,
    attendanceToday: results[3].count ?? 0,
    openQueries: results[4].count ?? 0,
  );
});

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminDashboardProvider);

    final tools = [
      _AdminItem('User Management', Icons.manage_accounts, '/admin/users'),
      _AdminItem('Manage Queries', Icons.live_help, '/admin/queries'),
      _AdminItem('Timetable Builder', Icons.edit_calendar, '/admin/timetable'),
      _AdminItem('Attendance Overrides', Icons.edit_note, '/admin/attendance-overrides'),
      _AdminItem('Internal Marks', Icons.grade, '/admin/internal-marks-overrides'),
      _AdminItem('Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
      _AdminItem('Students Directory', Icons.people_alt, '/students/directory'),
      _AdminItem('Teachers Directory', Icons.school, '/teachers/directory'),
      _AdminItem('Import / Export', Icons.import_export, '/admin/import-export'),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Admin Dashboard'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (vm) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Campus Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final half = width > 600 ? (width - 16) / 2 : width;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                        width: half,
                        icon: Icons.groups,
                        label: 'Total Users',
                        value: vm.totalUsers.toString(),
                        subtext: '${vm.totalStudents} Students • ${vm.totalTeachers} Teachers',
                        color: Colors.indigo,
                      ),
                      _StatCard(
                        width: half,
                        icon: Icons.today,
                        label: 'Attendance Today',
                        value: vm.attendanceToday.toString(),
                        subtext: 'Records marked today',
                        color: Colors.teal,
                      ),
                      _StatCard(
                        width: width,
                        icon: Icons.notifications_active,
                        label: 'Open Queries',
                        value: vm.openQueries.toString(),
                        subtext: vm.openQueries > 0 ? 'Requires attention' : 'All clear',
                        color: vm.openQueries > 0 ? Colors.orange : Colors.green,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Management Tools',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: tools.length,
                itemBuilder: (_, i) {
                  final item = tools[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    color: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      onTap: () => context.push(item.path),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, size: 32, color: Colors.white),
                            const SizedBox(height: 12),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminItem {
  final String title;
  final IconData icon;
  final String path;
  _AdminItem(this.title, this.icon, this.path);
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}