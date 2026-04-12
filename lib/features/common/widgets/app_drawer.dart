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
    final authRepo = ref.read(authRepoProvider);

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
            final commonMenu = [
              // --- NEW SHARED FEATURES ---
              const _DrawerItem(
                  'Campus Notices', Icons.campaign_outlined, '/notices'),
              const _DrawerItem(
                  'Assignments', Icons.assignment_outlined, '/assignments'),
              // ---------------------------
              const _DrawerItem(
                  'Teachers', Icons.school_outlined, '/teachers/directory'),
              const _DrawerItem(
                  'Students', Icons.people_alt_outlined, '/students/directory'),
              const _DrawerItem(
                  'Notifications', Icons.notifications_outlined, '/notifications'),
              const _DrawerItem(
                  'About', Icons.info_outline, '/about'),
            ];

            return Column(
              children: [
                // ----------------------------------------------------------------
                // HEADER
                // ----------------------------------------------------------------
                UserAccountsDrawerHeader(
                  accountName: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  accountEmail: Text(user.email ?? user.phone),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  otherAccountsPictures: const [
                    AnimatedThemeSwitcher(),
                  ],
                  onDetailsPressed: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),

                // ----------------------------------------------------------------
                // MENU
                // ----------------------------------------------------------------
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ...roleMenu.items.map((e) => _buildTile(context, e)),
                      const Divider(),
                      ...commonMenu.map((e) => _buildTile(context, e)),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ----------------------------------------------------------------
                // LOGOUT
                // ----------------------------------------------------------------
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await authRepo.logout();
                  },
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'v1.2.0 • © CampusTrack',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TILE BUILDER
  // ---------------------------------------------------------------------------

  Widget _buildTile(BuildContext context, _DrawerItem item) {
    final String currentPath = GoRouterState.of(context).uri.path;
    final bool isSelected = currentPath == item.route;

    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[700],
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.2),
      onTap: () {
        Navigator.pop(context);

        if (item.isHome) {
          // Dashboard should clear stack
          context.go(item.route);
        } else {
          if (currentPath != item.route) {
            context.push(item.route);
          }
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ROLE MENUS
  // ---------------------------------------------------------------------------

  _RoleMenu _getMenuForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return _RoleMenu('Admin Menu', [
          const _DrawerItem(
              'Dashboard', Icons.dashboard, '/home/admin',
              isHome: true),
          const _DrawerItem(
              'Users', Icons.manage_accounts, '/admin/users'),
          const _DrawerItem(
              'Queries', Icons.question_answer, '/admin/queries'),
          const _DrawerItem(
              'Timetable', Icons.edit_calendar, '/admin/timetable'),
          const _DrawerItem(
              'Attendance Overrides', Icons.edit_note, '/admin/attendance-overrides'),
          const _DrawerItem(
              'Marks Overrides', Icons.grade, '/admin/internal-marks-overrides'),
          const _DrawerItem(
              'Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
          const _DrawerItem(
              'Import / Export', Icons.import_export, '/admin/import-export'),
        ]);

      case UserRole.teacher:
        return _RoleMenu('Teacher Menu', [
          const _DrawerItem(
              'Dashboard', Icons.dashboard, '/home/teacher',
              isHome: true),
          const _DrawerItem(
              'Internal Marks', Icons.grading, '/teacher/internal-marks'),
          const _DrawerItem(
              'Remarks Board', Icons.label_important_outline, '/teacher/remarks-board'),
        ]);

      case UserRole.student:
        return _RoleMenu('Student Menu', [
          const _DrawerItem(
              'Dashboard', Icons.dashboard, '/home/student',
              isHome: true),
          const _DrawerItem(
              'Scan QR', Icons.qr_code_scanner, '/student/scan-qr'),
          const _DrawerItem(
              'Attendance', Icons.fact_check_outlined, '/student/attendance'),
          const _DrawerItem(
              'Marks', Icons.score, '/student/internal-marks'),
          const _DrawerItem(
              'Timetable', Icons.calendar_month_outlined, '/student/timetable'),
          const _DrawerItem(
              'Raise Query', Icons.live_help_outlined, '/student/raise-query'),
        ]);
    }
  }
}

// -----------------------------------------------------------------------------
// SUPPORTING MODELS
// -----------------------------------------------------------------------------

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