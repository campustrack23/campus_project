// lib/features/student/raise_query_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/models/subject.dart';
import '../../main.dart';

// Provider to fetch subjects for the dropdown
final subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) async {
  final ttRepo = ref.watch(timetableRepoProvider);
  final subjects = await ttRepo.allSubjects();
  subjects.sort((a, b) => a.name.compareTo(b.name));
  return subjects;
});

class RaiseQueryPage extends ConsumerStatefulWidget {
  const RaiseQueryPage({super.key});

  @override
  ConsumerState<RaiseQueryPage> createState() => _RaiseQueryPageState();
}

class _RaiseQueryPageState extends ConsumerState<RaiseQueryPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  String? _subjectId; // Can be null for 'General'
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Raise Query'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              subjectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading subjects: $err'),
                data: (subjects) => DropdownButtonFormField<String?>(
                  initialValue: _subjectId,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('General')),
                    ...subjects.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _subjectId = v),
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _message, maxLines: 5, decoration: const InputDecoration(labelText: 'Message'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submitQuery,
                  child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitQuery() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authRepoProvider);
      final user = await auth.currentUser();
      if (user == null) throw Exception('Not logged in');

      await ref.read(queryRepoProvider).raise(
        raisedByStudentId: user.id,
        subjectId: _subjectId,
        title: _title.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Query submitted')));
      context.pop(); // back
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}