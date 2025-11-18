import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user.dart';
import '../../../main.dart';

class ProfileAvatarAction extends ConsumerWidget {
  const ProfileAvatarAction({super.key});

  Stream<UserAccount?> _sessionStream(WidgetRef ref) async* {
    final auth = ref.read(authRepoProvider);
    yield await auth.currentUser();
    yield* auth.authStateChanges();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<UserAccount?>(
      stream: _sessionStream(ref),
      builder: (context, snap) {
        final user = snap.data;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            // **CHANGED**: onTap now navigates to the profile page
            onTap: user == null ? () => context.go('/login') : () => context.push('/profile'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user == null || user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
