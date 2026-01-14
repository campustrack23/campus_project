// lib/core/services/notification_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init({Function(String? payload)? onNotificationTap}) async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onNotificationTap != null) {
          onNotificationTap(response.payload);
        }
      },
    );

    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  Future<void> requestPermissions() async {
    if (!_initialized) await init();

    try {
      final androidImpl = _local
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
      }

      final iosImpl =
      _local.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      }

      final macImpl =
      _local.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macImpl != null) {
        await macImpl.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('NotificationService: Error requesting permissions: $e');
    }
  }

  Future<void> showLocal(String title, String body, {String? payload}) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'campustrack_local',
      'CampusTrack Notifications',
      channelDescription: 'Alerts for attendance and timetable changes',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final millisRemainder =
    DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final randomFallback = Random().nextInt(1000);
    final notificationId = millisRemainder + randomFallback;

    await _local.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

/// RIVERPOD PROVIDER
final notifServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
