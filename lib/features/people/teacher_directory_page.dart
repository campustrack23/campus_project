// lib/features/people/teacher_directory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';

import '../../core/models/role.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../main.dart';

// Provider to fetch teachers and subjects
final teacherDirectoryProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    ref.watch(allUsersProvider.future),
    ref.watch(timetableRepoProvider).allSubjects(),
  ]);

  final allUsers = results[0] as List<UserAccount>;
  final allSubjects = results[1] as List<Subject>;

  final teachers = allUsers.where((u) => u.role == UserRole.teacher).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  return (teachers: teachers, allSubjects: allSubjects);
});

class TeacherDirectoryPage extends ConsumerStatefulWidget {
  const TeacherDirectoryPage({super.key});

  @override
  ConsumerState<TeacherDirectoryPage> createState() => _TeacherDirectoryPageState();
}

class _TeacherDirectoryPageState extends ConsumerState<TeacherDirectoryPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(teacherDirectoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Teacher Directory'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Name, Subject, or Qualification...',
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                filled: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),

          // Teacher List
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => AsyncErrorWidget(
                message: err.toString(),
                onRetry: () => ref.invalidate(teacherDirectoryProvider),
              ),
              data: (data) {
                final teachers = data.teachers;
                final allSubjects = data.allSubjects;

                // Filter based on search query
                final filtered = teachers.where((t) {
                  final subjects = allSubjects.where((s) => s.teacherId == t.id).toList();

                  if (_q.isEmpty) return true;
                  final q = _q.toLowerCase();

                  final nameMatch = t.name.toLowerCase().contains(q);
                  final emailMatch = (t.email ?? '').toLowerCase().contains(q);
                  final qualsMatch = t.qualifications.any((qual) => qual.toLowerCase().contains(q));
                  final subjectMatch = subjects.any((s) => s.name.toLowerCase().contains(q));

                  return nameMatch || emailMatch || qualsMatch || subjectMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No teachers found.', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(teacherDirectoryProvider.future),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final teacher = filtered[index];
                      final subjects =
                      allSubjects.where((s) => s.teacherId == teacher.id).toList();

                      return ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          child:
                          Text(teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          subjects.isNotEmpty
                              ? subjects.map((s) => s.name).take(2).join(', ') +
                              (subjects.length > 2 ? '...' : '')
                              : (teacher.email ?? teacher.phone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        childrenPadding: const EdgeInsets.only(bottom: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.phone, size: 18),
                                    label: const Text('Call'),
                                    onPressed: () => _launchUrl('tel:${teacher.phone}'),
                                  ),
                                ),
                                if (teacher.email != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.email, size: 18),
                                      label: const Text('Email'),
                                      onPressed: () => _launchUrl('mailto:${teacher.email}'),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(indent: 16, endIndent: 16),
                          if (teacher.qualifications.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Qualifications',
                              icon: Icons.school,
                              children:
                              teacher.qualifications.map((q) => Text('• $q')).toList(),
                            ),
                          if (subjects.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Subjects Taught',
                              icon: Icons.book,
                              children: subjects
                                  .map((s) => Text('• ${s.code} - ${s.name} (Sec ${s.section})'))
                                  .toList(),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, {
        required String title,
        required IconData icon,
        required List<Widget> children,
      }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              )
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch requested action')),
        );
      }
    }
  }
}
