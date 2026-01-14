// lib/features/common/widgets/profile_avatar_action.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user.dart';
import '../../../main.dart';

class ProfileAvatarAction extends ConsumerWidget {
  const ProfileAvatarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // Not logged in: show login icon
          return IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Login',
            onPressed: () => context.go('/login'),
          );
        }

        // Logged in: show avatar with first letter
        final initial = user.name.trim().isNotEmpty
            ? user.name.trim()[0].toUpperCase()
            : '?';

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}
