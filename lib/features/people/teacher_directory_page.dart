// lib/features/people/teacher_directory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/subject.dart';
// --- FIX: Re-added the missing UserAccount import ---
import '../../core/models/user.dart';
import '../../main.dart';

// Provider to fetch teachers and subjects
final teacherDirectoryProvider = FutureProvider.autoDispose((ref) async {
  // Fetch users and subjects in parallel
  final results = await Future.wait([
    ref.watch(allUsersProvider.future),
    ref.watch(timetableRepoProvider).allSubjects(),
  ]);

  final allUsers = results[0] as List<UserAccount>;
  final allSubjects = results[1] as List<Subject>;

  final teachers = allUsers.where((u) => u.role == UserRole.teacher).toList();
  teachers.sort((a, b) => a.name.compareTo(b.name));

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, subject, or qualification...',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
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
                  return const Center(child: Text('No teachers found.'));
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(teacherDirectoryProvider.future),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final teacher = filtered[index];
                      final subjects = allSubjects.where((s) => s.teacherId == teacher.id).toList();

                      return ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(teacher.name.isNotEmpty ? teacher.name[0] : '?'),
                        ),
                        title: Text(teacher.name),
                        subtitle: Text(teacher.email ?? teacher.phone),
                        children: [
                          _buildContactTile(Icons.phone, teacher.phone, 'tel:${teacher.phone}'),
                          if (teacher.email != null)
                            _buildContactTile(Icons.email, teacher.email!, 'mailto:${teacher.email}'),

                          const Divider(height: 1, indent: 16, endIndent: 16),

                          if (teacher.qualifications.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Qualifications',
                              icon: Icons.school_outlined,
                              items: teacher.qualifications,
                            ),

                          if (subjects.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Subjects Taught',
                              icon: Icons.book_outlined,
                              items: subjects.map((s) => '${s.name} (${s.section})').toList(),
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

  Widget _buildSection(BuildContext context, {required String title, required IconData icon, required List<String> items}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...items.map(
                (item) => ListTile(
              dense: true,
              leading: Icon(icon, size: 20),
              title: Text(item, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String text, String url) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(text),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
    );
  }
}