import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/models/subject.dart';
import '../../main.dart';

// -----------------------------------------------------------------------------
// SUBJECTS PROVIDER (FOR DROPDOWN)
// -----------------------------------------------------------------------------

final subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) async {
  final ttRepo = ref.watch(timetableRepoProvider);
  final subjects = await ttRepo.allSubjects();
  subjects.sort((a, b) => a.name.compareTo(b.name));
  return subjects;
});

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------

class RaiseQueryPage extends ConsumerStatefulWidget {
  const RaiseQueryPage({super.key});

  @override
  ConsumerState<RaiseQueryPage> createState() => _RaiseQueryPageState();
}

class _RaiseQueryPageState extends ConsumerState<RaiseQueryPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  String? _subjectId; // null = General
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SUBMIT
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepoProvider);
      final queryRepo = ref.read(queryRepoProvider);

      final user = await authRepo.currentUser();
      if (user == null) {
        throw Exception('You must be logged in.');
      }

      await queryRepo.raise(
        raisedByStudentId: user.id,
        subjectId: _subjectId,
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Query submitted successfully')),
      );

      context.pop(); // Back to previous page
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
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
          key: _formKey,
          child: Column(
            children: [
              // ----------------------------------------------------------------
              // SUBJECT DROPDOWN (OPTIONAL)
              // ----------------------------------------------------------------
              subjectsAsync.when(
                loading: () =>
                const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text(
                  'Failed to load subjects: $err',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                data: (subjects) => DropdownButtonFormField<String?>(
                  initialValue: _subjectId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('General'),
                    ),
                    ...subjects.map(
                          (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _subjectId = v),
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ----------------------------------------------------------------
              // TITLE
              // ----------------------------------------------------------------
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // ----------------------------------------------------------------
              // MESSAGE
              // ----------------------------------------------------------------
              TextFormField(
                controller: _msgCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Describe your issue',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 24),

              // ----------------------------------------------------------------
              // SUBMIT BUTTON
              // ----------------------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send),
                  label: const Text('Submit Query'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
