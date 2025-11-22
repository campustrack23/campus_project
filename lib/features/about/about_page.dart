// lib/features/about/about_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const String appVersion = "1.1.0";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final titleStyle =
    theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final headingStyle =
    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            // FIX: safer drawer opening
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('About'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),

      // FIX: consistent Material spacing
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CampusTrack', style: titleStyle),
          const SizedBox(height: 6),
          const Text(
            'Your smart campus assistant for attendance, internal marks, notifications and timetables.',
          ),
          const Divider(height: 32),

          Text('Key Features', style: headingStyle),
          const SizedBox(height: 12),

          const _FeatureTile(
            icon: Icons.qr_code_scanner,
            title: 'QR Code Attendance',
            subtitle:
            'Teachers generate a time-limited QR code. Students scan to mark attendance automatically.',
          ),
          const _FeatureTile(
            icon: Icons.assessment,
            title: 'Internal Marks Management',
            subtitle:
            'Manage assignments, tests and attendance marks — publish when ready.',
          ),
          const _FeatureTile(
            icon: Icons.calendar_today_outlined,
            title: 'Dynamic Timetables',
            subtitle:
            'Updated timetables for students & teachers with offline caching.',
          ),
          const _FeatureTile(
            icon: Icons.notifications_active_outlined,
            title: 'Instant Notifications',
            subtitle:
            'Real-time alerts for query updates, timetable changes and attendance warnings.',
          ),
          const _FeatureTile(
            icon: Icons.contact_mail_outlined,
            title: 'Campus Directories',
            subtitle:
            'View students and teachers with qualification details.',
          ),

          const Divider(height: 32),

          Text("What's New (v$appVersion)", style: headingStyle),
          const SizedBox(height: 12),

          const _FeatureTile(
            icon: Icons.assessment_outlined,
            title: 'Internal Marks',
            subtitle:
            'Teachers can now grade & publish. Students see their published marks.',
          ),
          const _FeatureTile(
            icon: Icons.school_outlined,
            title: 'Teacher Qualifications',
            subtitle:
            'Teachers can now display qualifications in their directory profile.',
          ),

          const Divider(height: 32),

          Text('Technology & Credits', style: headingStyle),
          const SizedBox(height: 12),

          const _FeatureTile(
            icon: Icons.code,
            title: 'Flutter & Dart',
            subtitle:
            'Crafted with Flutter for a high-performance cross-platform experience.',
          ),
          const _FeatureTile(
            icon: Icons.local_fire_department_outlined,
            title: 'Firebase',
            subtitle:
            'Authentication, Firestore database, notifications — all securely powered by Firebase.',
          ),
          const _FeatureTile(
            icon: Icons.storage,
            title: 'Riverpod',
            subtitle:
            'Reliable and simple state management using Riverpod.',
          ),

          const Divider(height: 32),

          Text('Disclaimer', style: headingStyle),
          const SizedBox(height: 6),
          Text(
            'This app is provided as-is. All user data is stored securely in Firebase Firestore and governed by strict security rules.',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Version $appVersion',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: Text('© 2025 CampusTrack')),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      minLeadingWidth: 40,
      leading: Icon(icon, size: 28, color: primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }
}
