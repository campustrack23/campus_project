// lib/features/about/about_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

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
          const Text('Your smart campus assistant for attendance and timetables.'),
          const Divider(height: 32),

          Text('Key Features', style: headingStyle),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.qr_code_scanner,
            title: 'QR Code Attendance',
            subtitle: 'Teachers generate a unique, time-limited QR code. Students scan to mark themselves present.',
          ),
          const _FeatureTile(
            icon: Icons.assessment,
            title: 'Internal Marks Management',
            subtitle: 'Teachers can manage and publish internal assignment, test, and attendance marks for their subjects.',
          ),
          const _FeatureTile(
            icon: Icons.calendar_today_outlined,
            title: 'Dynamic Timetables',
            subtitle: 'Role-specific timetables that are always up-to-date for students and teachers, with offline access.',
          ),
          const _FeatureTile(
            icon: Icons.notifications_active_outlined,
            title: 'Instant Notifications',
            subtitle: 'Receive real-time alerts for timetable changes and query updates.',
          ),
          const _FeatureTile(
            icon: Icons.contact_mail_outlined,
            title: 'Campus Directories',
            subtitle: 'Access directories for all students and teachers, including teacher qualifications.',
          ),

          const Divider(height: 32),

          Text("What's New (v1.1.0)", style: headingStyle),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.assessment_outlined,
            title: 'Internal Marks',
            subtitle: 'Teachers can now grade and publish internal marks. Students can view their published grades.',
          ),
          const _FeatureTile(
            icon: Icons.school_outlined,
            title: 'Teacher Qualifications',
            subtitle: 'Teachers can add their qualifications to their profile, which are visible in the new Teacher Directory.',
          ),

          const Divider(height: 32),

          Text('Technology & Credits', style: headingStyle),
          const SizedBox(height: 12),
          const _FeatureTile(
            icon: Icons.code,
            title: 'Flutter & Dart',
            subtitle: 'Built with the Flutter framework for a cross-platform native experience.',
          ),
          const _FeatureTile(
            icon: Icons.local_fire_department_outlined,
            title: 'Firebase',
            subtitle: 'Powered by Firebase for Authentication, Firestore, and Storage (for future use).',
          ),
          const _FeatureTile(
            icon: Icons.storage,
            title: 'Riverpod',
            subtitle: 'State management handled cleanly and efficiently using Riverpod.',
          ),

          const Divider(height: 32),

          Text('Disclaimer', style: headingStyle),
          const SizedBox(height: 6),
          Text(
            'This application is provided as-is. All data is stored securely in Firebase Cloud Firestore and is protected by security rules.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Version 1.1.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('© 2025 CampusTrack'),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }
}