// lib/features/admin/admin_home_page.dart
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

final adminDashboardProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);
  final queryRepo = ref.watch(queryRepoProvider);

  final results = await Future.wait([
    authRepo.allUsers(),
    attRepo.allRecords(),
    queryRepo.allQueries(),
  ]);

  return {
    'users': results[0] as List<UserAccount>,
    'attendance': results[1] as List<AttendanceRecord>,
    'queries': results[2] as List<QueryTicket>,
  };
});

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(adminDashboardProvider);

    // --- FIX: Added new admin tools ---
    final items = [
      _AdminItem('User Management', Icons.group, '/admin/users'),
      _AdminItem('Manage Queries', Icons.question_answer, '/admin/queries'),
      _AdminItem('Timetable Builder', Icons.calendar_month, '/admin/timetable'),
      _AdminItem('Attendance Overrides', Icons.fact_check, '/admin/attendance-overrides'),
      _AdminItem('Internal Marks', Icons.assessment, '/admin/internal-marks-overrides'),
      _AdminItem('Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
      _AdminItem('Students Directory', Icons.people_alt, '/students/directory'),
      _AdminItem('Teacher Directory', Icons.contact_mail_outlined, '/teachers/directory'),
      _AdminItem('Import / Export', Icons.sim_card_download, '/admin/import-export'),
    ];
    // --- End of Fix ---

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
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
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (data) {
          final users = (data['users'] as List<UserAccount>);
          final attendance = (data['attendance'] as List<AttendanceRecord>);
          final queries = (data['queries'] as List<QueryTicket>);

          final studentCount = users.where((u) => u.role == UserRole.student).length;
          final teacherCount = users.where((u) => u.role == UserRole.teacher).length;
          final adminCount = users.where((u) => u.role == UserRole.admin).length;

          final now = DateTime.now();
          final attendanceToday = attendance.where((r) =>
          r.date.year == now.year &&
              r.date.month == now.month &&
              r.date.day == now.day
          ).length;

          final openQueries = queries.where((q) =>
          q.status == QueryStatus.open || q.status == QueryStatus.inProgress
          ).length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Campus Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      icon: Icons.group,
                      label: 'Total Users',
                      value: users.length.toString(),
                      subtext: '$studentCount Students, $teacherCount Teachers, $adminCount Admins',
                      color: Colors.blue.shade700,
                    ),
                    _StatCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance Marked Today',
                      value: attendanceToday.toString(),
                      subtext: 'Total records for today',
                      color: Colors.green.shade700,
                    ),
                    _StatCard(
                      icon: Icons.help_outline,
                      label: 'Open Queries',
                      value: openQueries.toString(),
                      subtext: 'Needs attention',
                      color: Colors.orange.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Admin Tools', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // --- FIX: Adjust grid to fit all items ---
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context, items.length),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: InkWell(
                        onTap: () => context.push(it.path),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(it.icon, size: 40, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(it.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to make grid responsive
  int _getCrossAxisCount(BuildContext context, int itemCount) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200 && itemCount > 8) return 4;
    if (width > 800 && itemCount > 5) return 3;
    return 2;
  }
}

class _AdminItem {
  final String title;
  final IconData icon;
  final String path;
  _AdminItem(this.title, this.icon, this.path);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text(subtext, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}