// lib/features/teacher/generate_qr_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secure_application/secure_application.dart';

import '../../core/models/attendance_session.dart';
import '../../core/models/timetable_entry.dart';
import '../common/widgets/async_error_widget.dart';
import '../../main.dart';

/// Provider to create and hold the session
final sessionProvider =
FutureProvider.autoDispose.family<AttendanceSession, String>((ref, entryId) async {
  final ttRepo = ref.watch(timetableRepoProvider);
  final authRepo = ref.watch(authRepoProvider);
  final attRepo = ref.watch(attendanceRepoProvider);

  final entry = await ttRepo.entryById(entryId);
  final user = await authRepo.currentUser();

  if (entry == null) throw Exception('Timetable entry not found.');
  if (user == null) throw Exception('User not logged in.');

  final session = await attRepo.createAttendanceSession(
    teacherId: user.id,
    subjectId: entry.subjectId,
    section: entry.section,
    slot: entry.slot,
  );
  return session;
});

/// Provider to listen to the attendees
final attendeesStreamProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>(
        (ref, sessionId) {
      return ref.watch(attendanceRepoProvider).listenToAttendees(sessionId);
    });

class GenerateQRPage extends ConsumerStatefulWidget {
  final String? entryId;
  const GenerateQRPage({super.key, this.entryId});

  @override
  ConsumerState<GenerateQRPage> createState() => _GenerateQRPageState();
}

class _GenerateQRPageState extends ConsumerState<GenerateQRPage> {
  Timer? _timer;
  int _secondsRemaining = 600; // 10 minutes

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entryId == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Error: No class ID provided.')));
    }

    final asyncSession = ref.watch(sessionProvider(widget.entryId!));

    return SecureApplication(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mark Attendance'),
        ),
        body: asyncSession.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(sessionProvider(widget.entryId!)),
          ),
          data: (session) {
            final asyncAttendees = ref.watch(attendeesStreamProvider(session.id));
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Scan to Mark Attendance',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Session expires in:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _formatTime(_secondsRemaining),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _secondsRemaining < 60 ? Colors.red : null),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: session.id,
                        version: QrVersions.auto,
                        size: 250.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    asyncAttendees.when(
                      loading: () => const Text('Waiting for students...'),
                      error: (e, s) =>
                          Text('Error: $e', style: const TextStyle(color: Colors.red)),
                      data: (attendees) => Text(
                        '${attendees.length} Students Marked',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          _timer?.cancel();

                          final messenger = ScaffoldMessenger.of(context);

                          final allStudents =
                          await ref.read(authRepoProvider).allStudents();
                          final studentsInSection = allStudents
                              .where((s) =>
                          (s.section ?? '').toUpperCase() ==
                              session.section.toUpperCase())
                              .toList();

                          await ref.read(attendanceRepoProvider).finalizeAttendance(
                            sessionId: session.id,
                            studentsInSection: studentsInSection,
                          );

                          if (!mounted) return;

                          // FIX: Use Path Parameter format (/path/id) instead of Query Parameter (?id=...)
                          GoRouter.of(context).replace('/teacher/review-attendance/${session.id}');

                          messenger.showSnackBar(
                            const SnackBar(content: Text('Attendance finalized')),
                          );
                        },
                        child: const Text('Done', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}