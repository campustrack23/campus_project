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

class _ScanQRPageState extends ConsumerState<ScanQRPage> with WidgetsBindingObserver {
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

  // --- LIFECYCLE MANAGEMENT ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
  // ---------------------------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final String? sessionId = capture.barcodes.first.rawValue;
    if (sessionId == null || sessionId.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final user = await ref.read(authRepoProvider).currentUser();
      if (user == null) throw Exception('You are not logged in.');

      final message = await ref.read(attendanceRepoProvider).markStudentPresent(
        sessionId: sessionId, studentId: user.id, studentName: user.name,
      );

      if (!mounted) return;
      await _showSuccess(context, message);
      if (!mounted) return;
      GoRouter.of(context).pop();
    } catch (e) {
      _showError(e.toString());
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSuccess(BuildContext context, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Success!'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceAll('Exception: ', '')), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance QR'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) => Icon(state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(_cameraFacing == CameraFacing.front ? Icons.camera_front : Icons.camera_rear),
            onPressed: () async {
              await _controller.switchCamera();
              setState(() => _cameraFacing = _cameraFacing == CameraFacing.front ? CameraFacing.back : CameraFacing.front);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(padding: EdgeInsets.all(16), child: Text("Align QR code here", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}