// lib/features/notices/notices_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/models/role.dart';
import '../../core/models/user.dart';
import '../../main.dart';

// --- PROVIDER ---
final noticesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) return [];

  final allNotices = await ref.watch(apiServiceProvider).getNotices();

  // 🔴 FILTERING LOGIC: Students only see notices meant for them or everyone.
  if (user.role == UserRole.student) {
    return allNotices.where((n) {
      final target = (n['targetAudience'] ?? n['target_audience'])?.toString() ?? 'all';
      return target == 'all' || target == 'students';
    }).toList();
  }

  // Teachers and Admins can see all notices
  return allNotices;
});

// --- MAIN PAGE ---
class NoticesPage extends ConsumerWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotices = ref.watch(noticesProvider);
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notices'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: asyncNotices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (notices) {
          if (notices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No notices available.', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(noticesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notices.length,
              itemBuilder: (ctx, i) {
                final notice = notices[i];
                return _NoticeCard(notice: notice);
              },
            ),
          );
        },
      ),
      floatingActionButton: userAsync.maybeWhen(
        data: (user) {
          if (user != null && user.role != UserRole.student) {
            return FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              onPressed: () => _showAddNoticeDialog(context, user),
              icon: const Icon(Icons.add),
              label: const Text('Post Notice'),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  void _showAddNoticeDialog(BuildContext context, UserAccount currentUser) {
    showDialog(
      context: context,
      builder: (ctx) => _AddNoticeDialog(currentUser: currentUser),
    );
  }
}

// --- PROFESSIONAL NOTICE CARD UI ---
class _NoticeCard extends StatelessWidget {
  final dynamic notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final title = notice['title'] ?? 'Untitled Notice';
    final content = notice['content'] ?? 'No content provided.';
    final authorName = notice['authorName'] ?? notice['author_name'] ?? 'Admin';
    final authorRole = notice['authorRole'] ?? notice['author_role'] ?? 'Staff';
    final target = notice['targetAudience'] ?? notice['target_audience'] ?? 'all';

    // 🟢 FOOLPROOF DATE PARSING
    final rawDate = notice['createdAt'] ?? notice['created_at'];
    String dateStr = 'Recently';

    if (rawDate != null) {
      try {
        // Attempt 1: Standard ISO-8601 (e.g. 2026-03-23T05:53:40Z)
        final dt = DateTime.parse(rawDate.toString());
        dateStr = DateFormat('MMM d, yyyy').format(dt);
      } catch (_) {
        try {
          // Attempt 2: Flask/HTTP Format (e.g. Mon, 23 Mar 2026 05:53:40 GMT)
          final dt = DateFormat("E, d MMM yyyy HH:mm:ss 'GMT'").parse(rawDate.toString(), true);
          dateStr = DateFormat('MMM d, yyyy').format(dt.toLocal());
        } catch (_) {
          // Attempt 3: If both fail, safely show a piece of the raw string without crashing
          dateStr = rawDate.toString().length > 12
              ? rawDate.toString().substring(0, 12)
              : rawDate.toString();
        }
      }
    }

    Color badgeColor = Colors.grey;
    String badgeText = 'All Users';
    if (target == 'students') {
      badgeColor = Colors.blue;
      badgeText = 'Students Only';
    } else if (target == 'teachers') {
      badgeColor = Colors.orange;
      badgeText = 'Teachers Only';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                        style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(authorRole.toString().toUpperCase(), style: TextStyle(color: Colors.grey.shade600, fontSize: 10, letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- STATEFUL CREATE DIALOG ---
class _AddNoticeDialog extends ConsumerStatefulWidget {
  final UserAccount currentUser;
  const _AddNoticeDialog({required this.currentUser});

  @override
  ConsumerState<_AddNoticeDialog> createState() => _AddNoticeDialogState();
}

class _AddNoticeDialogState extends ConsumerState<_AddNoticeDialog> {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  String _selectedTarget = 'all';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post New Notice'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send to:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              initialValue: _selectedTarget,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Everyone (All Users)')),
                DropdownMenuItem(value: 'students', child: Text('Students Only')),
                DropdownMenuItem(value: 'teachers', child: Text('Teachers Only')),
              ],
              onChanged: (val) => setState(() => _selectedTarget = val!),
            ),
            const SizedBox(height: 16),

            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Message Content', border: OutlineInputBorder()), maxLines: 4),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: _isLoading ? null : _submitNotice,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send, size: 18),
          label: const Text('Publish'),
        ),
      ],
    );
  }

  Future<void> _submitNotice() async {
    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(apiServiceProvider).createNotice({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'targetAudience': _selectedTarget,
        'authorName': widget.currentUser.name,
        'authorRole': widget.currentUser.role.key,
        'createdAt': DateTime.now().toIso8601String(),
      });

      ref.invalidate(noticesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice published successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}