// lib/features/auth/splash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- THIS PAGE IS NOW SIMPLIFIED ---
// All navigation logic is handled by the GoRouter redirect in main.dart,
// making the app start faster. This page is just a simple UI.

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bg = Color(0xFFCBD2F0);
    const card = Color(0xFF2D232C);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 6))
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, color: Colors.white, size: 42),
              SizedBox(height: 10),
              Text('CAMPUS TRACK',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              SizedBox(height: 6),
              Text('Attendance & Timetable',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center),
              SizedBox(height: 16),
              SizedBox(
                height: 18,
                width: 18,
                child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}