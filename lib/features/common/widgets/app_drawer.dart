// lib/features/common/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart';
import '../../../core/models/role.dart';
import '../../../main.dart';
import 'animated_theme_switcher.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final authRepo = ref.read(authRepoProvider);

    return Drawer(
      child: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Could not load user')),
          data: (user) {
            if (user == null) return const SizedBox();

            final menu = _getMenuForRole(user.role);
            final common = [
              const _DrawerItem('Teachers', Icons.school_outlined, '/teachers/directory'),
              const _DrawerItem('Students', Icons.people_alt_outlined, '/students/directory'),
              const _DrawerItem('Notifications', Icons.notifications_outlined, '/notifications'),
              const _DrawerItem('About', Icons.info_outline, '/about'),
            ];

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  title: Text(menu.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  subtitle: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const AnimatedThemeSwitcher(),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ...menu.items.map((item) => _buildTile(context, item)),
                      const Divider(),
                      ...common.map((item) => _buildTile(context, item)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    authRepo.logout();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('v1.1.0 • © CampusTrack', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _DrawerItem item) {
    return ListTile(
      leading: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
      title: Text(item.title),
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.pop(context);
        if (router.routeInformationProvider.value.uri.path == item.route) return;
        if (item.isHome) {
          router.go(item.route);
        } else {
          router.push(item.route);
        }
      },
    );
  }

  _RoleMenu _getMenuForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return _RoleMenu('Admin Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/admin', isHome: true),
          const _DrawerItem('Users', Icons.manage_accounts, '/admin/users'),
          const _DrawerItem('Queries', Icons.question_answer, '/admin/queries'),
          const _DrawerItem('Timetable', Icons.edit_calendar, '/admin/timetable'),
          const _DrawerItem('Att. Overrides', Icons.edit_note, '/admin/attendance-overrides'),
          const _DrawerItem('Marks Overrides', Icons.grade, '/admin/internal-marks-overrides'),
          const _DrawerItem('Passwords', Icons.lock_reset, '/admin/reset-passwords'),
          const _DrawerItem('Data I/O', Icons.import_export, '/admin/import-export'),
        ]);
      case UserRole.teacher:
        return _RoleMenu('Teacher Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/teacher', isHome: true),
          const _DrawerItem('Internal Marks', Icons.grading, '/teacher/internal-marks'),
          const _DrawerItem('Remarks Board', Icons.label_important_outline, '/teacher/remarks'),
        ]);
      case UserRole.student:
        return _RoleMenu('Student Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/student', isHome: true),
          const _DrawerItem('Attendance', Icons.fact_check_outlined, '/student/attendance'),
          const _DrawerItem('Marks', Icons.score, '/student/internal-marks'),
          const _DrawerItem('Timetable', Icons.calendar_month_outlined, '/student/timetable'),
          const _DrawerItem('Raise Query', Icons.live_help_outlined, '/student/raise-query'),
        ]);
    }
  }
}

class _RoleMenu {
  final String title;
  final List<_DrawerItem> items;
  _RoleMenu(this.title, this.items);
}

class _DrawerItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isHome;
  const _DrawerItem(this.title, this.icon, this.route, {this.isHome = false});
}