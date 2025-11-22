// lib/features/admin/admin_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/query_ticket.dart';
import '../../core/models/user.dart';
import '../../core/models/attendance.dart';
import '../../main.dart';

// --- VIEW MODEL ---
class AdminDashboardVM {
  final int totalStudents;
  final int totalTeachers;
  final int attendanceToday;
  final int openQueries;
  final int totalUsers;

  AdminDashboardVM({
    required this.totalStudents,
    required this.totalTeachers,
    required this.attendanceToday,
    required this.openQueries,
    required this.totalUsers,
  });
}

// --- OPTIMIZED PROVIDER ---
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardVM>((ref) async {
  // 1. KeepAlive: Cache data for 5 minutes
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () => link.close());
  ref.onDispose(() => timer.cancel());

  final authRepo = ref.watch(authRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);
  final queryRepo = ref.watch(queryRepoProvider);

  // 2. Parallel Fetch
  final results = await Future.wait([
    authRepo.allUsers(),
    attRepo.allRecords(),
    queryRepo.allQueries(),
  ]);

  final users = results[0] as List<UserAccount>;
  final attendance = results[1] as List<AttendanceRecord>;
  final queries = results[2] as List<QueryTicket>;

  // 3. Background Calculation (Off UI thread logic)
  final studentCount = users.where((u) => u.role == UserRole.student).length;
  final teacherCount = users.where((u) => u.role == UserRole.teacher).length;

  final now = DateTime.now();
  final todayRecords = attendance.where((r) =>
  r.date.year == now.year && r.date.month == now.month && r.date.day == now.day
  ).length;

  final activeQueries = queries.where((q) =>
  q.status == QueryStatus.open || q.status == QueryStatus.inProgress
  ).length;

  return AdminDashboardVM(
    totalStudents: studentCount,
    totalTeachers: teacherCount,
    totalUsers: users.length,
    attendanceToday: todayRecords,
    openQueries: activeQueries,
  );
});

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminDashboardProvider);

    final items = [
      _AdminItem('User Management', Icons.manage_accounts, '/admin/users'),
      _AdminItem('Manage Queries', Icons.live_help, '/admin/queries'),
      _AdminItem('Timetable Builder', Icons.edit_calendar, '/admin/timetable'),
      _AdminItem('Attendance Overrides', Icons.edit_note, '/admin/attendance-overrides'),
      _AdminItem('Internal Marks', Icons.grade, '/admin/internal-marks-overrides'),
      _AdminItem('Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
      _AdminItem('Students Directory', Icons.people_alt, '/students/directory'),
      _AdminItem('Teacher Directory', Icons.school, '/teachers/directory'),
      _AdminItem('Import / Export', Icons.import_export, '/admin/import-export'),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu', icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Admin Dashboard'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (vm) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(adminDashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Campus Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    return Wrap(
                      spacing: 16, runSpacing: 16,
                      children: [
                        _StatCard(
                          width: width > 600 ? (width - 32) / 2 : width,
                          icon: Icons.groups,
                          label: 'Total Users',
                          value: vm.totalUsers.toString(),
                          subtext: '${vm.totalStudents} Students • ${vm.totalTeachers} Teachers',
                          color: Colors.indigo,
                        ),
                        _StatCard(
                          width: width > 600 ? (width - 32) / 2 : width,
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
                          color: vm.openQueries > 0 ? Colors.orange.shade800 : Colors.green,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text('Management Tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      color: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        onTap: () => context.push(item.path),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.icon, size: 32, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(item.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
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
          );
        },
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

  const _StatCard({required this.width, required this.icon, required this.label, required this.value, required this.subtext, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtext, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}