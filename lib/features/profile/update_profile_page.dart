// lib/features/profile/update_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/firebase_error_parser.dart';
import '../../main.dart';

final externalProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(authRepoProvider).currentUser();
  if (user == null) throw Exception('User not logged in');
  return ref.watch(apiServiceProvider).getProfile(user.id);
});

class UpdateProfilePage extends ConsumerStatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  ConsumerState<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends ConsumerState<UpdateProfilePage> {
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(externalProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Update External Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(FirebaseErrorParser.getMessage(err))),
        data: (profileData) {
          if (_bioCtrl.text.isEmpty && profileData.containsKey('bio')) {
            _bioCtrl.text = profileData['bio']?.toString() ?? '';
          }
          if (_phoneCtrl.text.isEmpty && profileData.containsKey('phone')) {
            _phoneCtrl.text = profileData['phone']?.toString() ?? '';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : () => _updateProfile(ref),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateProfile(WidgetRef ref) async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authRepoProvider).currentUser();
      await ref.read(apiServiceProvider).updateProfile(user!.id, {
        'bio': _bioCtrl.text,
        'phone': _phoneCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // SECURITY FIX: Route error through parser
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FirebaseErrorParser.getMessage(e)))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}