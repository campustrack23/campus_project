// lib/features/about/about_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const String appVersion = "1.0.0";

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
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('About'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
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
            'Automated calculation of attendance scores and internal assessments.',
          ),
          const _FeatureTile(
            icon: Icons.calendar_today_outlined,
            title: 'Dynamic Timetables',
            subtitle:
            'Live timetables for students & teachers with offline caching.',
          ),
          const _FeatureTile(
            icon: Icons.live_help_outlined,
            title: 'Help Desk',
            subtitle:
            'Raise queries directly to the administration and track their status in real-time.',
          ),

          const Divider(height: 32),

          Text('Developed By', style: headingStyle),
          const SizedBox(height: 12),
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.code)),
            title: Text('Mohit Chauhan & Yash Gulati'),
            subtitle: Text('Full Stack Flutter Developers'),
          ),

          const Divider(height: 32),

          Text('Technology', style: headingStyle),
          const SizedBox(height: 12),

          const _FeatureTile(
            icon: Icons.flutter_dash,
            title: 'Flutter & Riverpod',
            subtitle: 'High-performance cross-platform UI with robust state management.',
          ),
          const _FeatureTile(
            icon: Icons.cloud_circle,
            title: 'Firebase',
            subtitle: 'Powered by Firestore, Cloud Functions, and Firebase Auth.',
          ),

          const SizedBox(height: 40),

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