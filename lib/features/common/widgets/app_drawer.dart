// lib/features/common/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/role.dart';
import '../../../main.dart';
import 'animated_theme_switcher.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Drawer(
      child: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Not logged in'));
            }

            final roleMenu = _getMenuForRole(user.role);

            // SECURITY FIX: Removed "Students Directory" from the common menu
            final commonMenu = [
              const _DrawerItem('Campus Notices', Icons.campaign_outlined, '/notices'),
              const _DrawerItem('Assignments', Icons.assignment_outlined, '/assignments'),
              const _DrawerItem('Teachers', Icons.school_outlined, '/teachers/directory'),
              const _DrawerItem('My Profile', Icons.person_outline, '/profile'),
              const _DrawerItem('About', Icons.info_outline, '/about'),
            ];

            return Column(
              children: [
                _buildHeader(context, user.name, user.email ?? user.phone, user.role.label),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildSectionTitle(roleMenu.title),
                      ...roleMenu.items.map((item) => _buildItem(context, item)),
                      const Divider(height: 32),
                      _buildSectionTitle('General'),
                      ...commonMenu.map((item) => _buildItem(context, item)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const AnimatedThemeSwitcher(),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        onPressed: () async {
                          await ref.read(authRepoProvider).logout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String subtitle, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildItem(BuildContext context, _DrawerItem item) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == item.route || (item.isHome && currentRoute.startsWith('/home'));

    return ListTile(
      leading: Icon(item.icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(item.title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      onTap: () {
        Navigator.pop(context); // Close drawer

        // NAVIGATION FIX:
        // Dashboards use 'go' to reset the stack.
        // Everything else uses 'push' to enable the back button history!
        if (item.isHome) {
          context.go(item.route);
        } else {
          context.push(item.route);
        }
      },
    );
  }

  _RoleMenu _getMenuForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return _RoleMenu('Admin Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/admin', isHome: true),
          const _DrawerItem('Users', Icons.people, '/admin/users'),
          const _DrawerItem('Students Directory', Icons.badge_outlined, '/students/directory'),
          const _DrawerItem('Timetable Builder', Icons.calendar_today, '/admin/timetable'),
          const _DrawerItem('Query Tickets', Icons.support_agent, '/admin/query-management'),
          const _DrawerItem('Attendance Overrides', Icons.edit_calendar, '/admin/attendance-overrides'),
          const _DrawerItem('Marks Overrides', Icons.edit_document, '/admin/internal-marks-overrides'),
          const _DrawerItem('Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
          const _DrawerItem('Import Data', Icons.upload_file, '/admin/import-export'),
        ]);

      case UserRole.teacher:
        return _RoleMenu('Teacher Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/teacher', isHome: true),
          const _DrawerItem('Students Directory', Icons.badge_outlined, '/students/directory'),
          const _DrawerItem('Internal Marks', Icons.grading, '/teacher/internal-marks'),
          const _DrawerItem('Remarks Board', Icons.label_important_outline, '/teacher/remarks-board'),
        ]);

      case UserRole.student:
        return _RoleMenu('Student Menu', [
          const _DrawerItem('Dashboard', Icons.dashboard, '/home/student', isHome: true),
          const _DrawerItem('Scan QR', Icons.qr_code_scanner, '/student/scan-qr'),
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

  const _DrawerItem(
      this.title,
      this.icon,
      this.route, {
        this.isHome = false,
      });
}