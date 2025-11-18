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

    return Drawer(
      child: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Center(child: Text('Could not load user')),
          data: (user) {
            final role = user?.role;
            List<_DrawerItem> items;
            String title;

            final baseItems = [
              _DrawerItem('Teacher Directory', Icons.contact_mail_outlined, '/teachers/directory'),
              _DrawerItem('Students Directory', Icons.people_alt, '/students/directory'),
              _DrawerItem('Notifications', Icons.notifications, '/notifications'),
              _DrawerItem('About', Icons.info_outline, '/about'),
            ];

            if (role == UserRole.admin) {
              title = 'Admin Menu';
              items = [
                _DrawerItem('Home', Icons.home, '/home/admin', isHome: true),
                _DrawerItem('Manage Queries', Icons.question_answer, '/admin/queries'),
                _DrawerItem('User Management', Icons.group, '/admin/users'),
                _DrawerItem('Timetable Builder', Icons.calendar_month, '/admin/timetable'),
                _DrawerItem('Attendance Overrides', Icons.fact_check, '/admin/attendance-overrides'),
                _DrawerItem('Reset Passwords', Icons.lock_reset, '/admin/reset-passwords'),
                ...baseItems,
              ];
            } else if (role == UserRole.teacher) {
              title = 'Teacher Menu';
              items = [
                _DrawerItem('Home', Icons.home, '/home/teacher', isHome: true),
                _DrawerItem('Internal Marks', Icons.assessment, '/teacher/internal-marks'),
                _DrawerItem('Remarks Board', Icons.label_important_outline, '/teacher/remarks'),
                ...baseItems,
              ];
            } else { // Handles both student and null user (logged out) cases
              title = 'Student Menu';
              items = [
                _DrawerItem('Home', Icons.home, '/home/student', isHome: true),
                _DrawerItem('My Attendance', Icons.fact_check, '/student/attendance'),
                _DrawerItem('Internal Marks', Icons.assessment, '/student/internal-marks'),
                _DrawerItem('Timetable', Icons.calendar_today, '/student/timetable'),
                _DrawerItem('Raise Query', Icons.help_center, '/student/raise-query'),
                ...baseItems,
              ];
            }

            Widget tile(_DrawerItem it) => ListTile(
              leading: Icon(it.icon),
              title: Text(it.title),
              onTap: () {
                final router = GoRouter.of(context);
                final currentPath = router.routeInformationProvider.value.uri.path;

                // Close the drawer first
                Navigator.pop(context);

                // --- FIX: Implement hybrid navigation ---
                // 1. If it's a "Home" link, always use .go() to reset the stack
                if (it.isHome) {
                  router.go(it.route);
                }
                // 2. If it's any other link, use .push()
                else {
                  // Only push if we are not already on that page
                  if (currentPath != it.route) {
                    router.push(it.route);
                  }
                }
                // --- End of Fix ---
              },
            );

            return Column(
              children: [
                ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: user == null
                      ? null
                      : Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const AnimatedThemeSwitcher(),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView(children: items.map(tile).toList()),
                ),
                const Divider(height: 0),
                ListTile(
                  dense: true,
                  title: Center(
                    child: Text('© ${DateTime.now().year} CampusTrack', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isHome; // Flag to identify home routes
  _DrawerItem(this.title, this.icon, this.route, {this.isHome = false});
}