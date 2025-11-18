// lib/features/common/widgets/profile_header.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/role.dart';
import '../../../core/models/user.dart';
import '../../../main.dart';

class ProfileHeader extends ConsumerWidget {
  final EdgeInsetsGeometry margin;
  const ProfileHeader({super.key, this.margin = const EdgeInsets.all(16)});

  Stream<UserAccount?> _sessionStream(WidgetRef ref) async* {
    final auth = ref.read(authRepoProvider);
    yield await auth.currentUser(); // initial
    yield* auth.authStateChanges(); // subsequent
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<UserAccount?>(
      stream: _sessionStream(ref),
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) return const SizedBox.shrink();
        final subtitle = u.email?.isNotEmpty == true ? u.email! : u.phone;
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2D232C),
              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${u.role.label} • $subtitle',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: (u.role == UserRole.student && u.collegeRollNo != null)
                ? FittedBox(child: Text('CR: ${u.collegeRollNo}', style: const TextStyle(fontWeight: FontWeight.w600)))
                : null,
          ),
        );
      },
    );
  }
}