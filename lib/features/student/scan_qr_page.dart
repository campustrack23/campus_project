// lib/features/student/scan_qr_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/utils/firebase_error_parser.dart';
import '../../main.dart';

class ScanQRPage extends ConsumerStatefulWidget {
  const ScanQRPage({super.key});

  @override
  ConsumerState<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends ConsumerState<ScanQRPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  bool _isProcessing = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _cameraFacing,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // APP LIFECYCLE FIX: Prevents Android black-screen camera crash
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      // Delay allows the Android UI surface to mount before starting the lens
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _controller.start();
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final user = await ref.read(authRepoProvider).currentUser();
      if (user == null) throw Exception('User not logged in');

      // SECURITY FIX: Parse the dynamic payload and enforce TTL
      final payload = jsonDecode(code);
      final String sessionId = payload['sId'];
      final int timestamp = payload['ts'];

      final now = DateTime.now().millisecondsSinceEpoch;
      // 15 seconds maximum validity window to prevent screenshot sharing
      if (now - timestamp > 15000) {
        throw Exception('QR Code expired. Please scan the live code directly from the teacher\'s screen.');
      }

      await ref.read(attendanceRepoProvider).markPresentSecure(
        sessionId: sessionId,
        studentId: user.id,
      );

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Attendance Marked!'),
            content: const Text('You have been successfully marked present.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home/student');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = FirebaseErrorParser.getMessage(e);

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text('Failed'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    setState(() => _isProcessing = false);
                  }
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(
              _cameraFacing == CameraFacing.back
                  ? Icons.camera_front
                  : Icons.camera_rear,
            ),
            onPressed: () {
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back
                    ? CameraFacing.front
                    : CameraFacing.back;
              });
              _controller.switchCamera();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (ctx, err, _) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Camera Error: ${err.errorCode}'),
                  ],
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Align QR code here',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black)
                        ]
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Verifying...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}