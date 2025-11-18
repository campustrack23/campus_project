// lib/features/student/scan_qr_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../main.dart';

class ScanQRPage extends ConsumerStatefulWidget {
  const ScanQRPage({super.key});

  @override
  ConsumerState<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends ConsumerState<ScanQRPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final String? sessionId = capture.barcodes.first.rawValue;
    if (sessionId == null || sessionId.isEmpty) {
      _showError('Invalid QR code.');
      // --- FIX: Reset processing state on invalid code ---
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
      // --- End of Fix ---
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = await ref.read(authRepoProvider).currentUser();
      if (user == null) throw Exception('You are not logged in.');

      final message = await ref.read(attendanceRepoProvider).markStudentPresent(
        sessionId: sessionId,
        studentId: user.id,
        studentName: user.name,
      );

      if (!mounted) return;
      await _showSuccess(context, message);

      if (!mounted) return;
      GoRouter.of(context).pop();
    } catch (e) {
      _showError(e.toString());
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  Future<void> _showSuccess(BuildContext context, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success!'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance QR'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _torchOn = !_torchOn;
              });
            },
          ),
          IconButton(
            icon: Icon(_cameraFacing == CameraFacing.front
                ? Icons.camera_front
                : Icons.camera_rear),
            onPressed: () async {
              await _controller.switchCamera();
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.front
                    ? CameraFacing.back
                    : CameraFacing.front;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withAlpha(128), width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Verifying...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}