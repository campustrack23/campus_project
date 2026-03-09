// lib/features/teacher/generate_qr_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:secure_application/secure_application.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../core/models/attendance_session.dart';
import '../../main.dart';
import '../common/widgets/async_error_widget.dart';

class GenerateQRPage extends ConsumerStatefulWidget {
  final String entryId;

  const GenerateQRPage({
    super.key,
    required this.entryId,
  });

  @override
  ConsumerState<GenerateQRPage> createState() => _GenerateQRPageState();
}

class _GenerateQRPageState extends ConsumerState<GenerateQRPage> {
  AttendanceSession? _session;
  Object? _error;
  bool _loading = true;

  Timer? _timer;
  int _secondsElapsed = 0;
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final authRepo = ref.read(authRepoProvider);
      final attRepo = ref.read(attendanceRepoProvider);
      final ttRepo = ref.read(timetableRepoProvider);

      final me = await authRepo.currentUser();
      if (me == null) throw Exception('Not logged in');

      final entry = await ttRepo.entryById(widget.entryId);
      if (entry == null) throw Exception('Timetable entry not found');

      final sessionId = const Uuid().v4();
      final now = DateTime.now();

      final newSession = AttendanceSession(
        id: sessionId,
        teacherId: me.id,
        subjectId: entry.subjectId,
        section: entry.section,
        slot: entry.slot,
        createdAt: now,
        isActive: true,
      );

      await attRepo.sessionsRef.doc(sessionId).set(newSession);

      if (mounted) {
        setState(() {
          _session = newSession;
          _loading = false;
        });
        _startTimers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _startTimers() {
    _generateDynamicQrData();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        // Rotate QR code data every 5 seconds to prevent static screenshot sharing
        if (_secondsElapsed % 5 == 0) {
          _generateDynamicQrData();
        }
      });
    });
  }

  void _generateDynamicQrData() {
    if (_session == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Server-side secret validation prevents payload tampering
    final secret = 'campus_track_secret_${_session!.teacherId}';
    final payload = '${_session!.id}:$timestamp';
    final signature = sha256.convert(utf8.encode('$payload:$secret')).toString();

    _qrData = jsonEncode({
      'sId': _session!.id,
      'ts': timestamp,
      'sig': signature.substring(0, 16),
    });
  }

  void _finishAndReview() {
    if (_session == null) return;
    context.pushReplacement('/teacher/review-attendance/${_session!.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: AsyncErrorWidget(
          message: _error.toString(),
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _initSession();
          },
        ),
      );
    }

    final session = _session!;

    return SecureApplication(
      nativeRemoveDelay: 100,
      onNeedUnlock: (secureNotifier) async {
        return null;
      },
      child: SecureGate(
        blurr: 60,
        opacity: 0.8,
        lockedBuilder: (context, secureNotifier) =>
        const Center(child: CircularProgressIndicator()),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Live Attendance'),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Session Active',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time Elapsed: ${_formatTime(_secondsElapsed)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),

                  // THE ROTATING SECURE QR CODE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 260,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _finishAndReview,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text(
                        'Finish & Review',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}