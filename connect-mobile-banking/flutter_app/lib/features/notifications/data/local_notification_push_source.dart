import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/assist_intent.dart';

// The simulated push: a real notification from the phone's own notification system (in the tray and on the lock
// screen), carrying the same `data` a push would, as its payload. Its taps go to the same handler as a real push.
// docs/CONTRACT.md section 7, "Simulated push: real local notifications".
//
// Scheduled with zonedSchedule (an inexact Android alarm, which needs no exact-alarm permission; an iOS time
// trigger), so it still arrives when the phone is locked or the app is in the background.
class LocalNotificationPushSource implements PushSource, LocalNotifier {
  LocalNotificationPushSource([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<Map<String, Object?>>.broadcast();
  bool _started = false;

  static const _channel = AndroidNotificationChannel(
    'money_alerts',
    'Money alerts',
    description: 'Payments, money in and out, balances and savings goals',
    importance: Importance.high,
  );

  @override
  Stream<Map<String, Object?>> get taps => _taps.stream;

  @override
  Stream<({String title, String body, Map<String, Object?> data})> get foreground => const Stream.empty(); // the system shows these

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_money'),
          // Permission is asked the first time "Send notification" is pressed, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final data = decodePayload(response.payload);
          if (data != null) _taps.add(data);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (error) {
      debugPrint('local notifications unavailable: ${error.runtimeType}');
    }
  }

  @override
  Future<Map<String, Object?>?> launchData() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return decodePayload(details.notificationResponse?.payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NotifyPermission> ensurePermission() async {
    try {
      bool? granted;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: true);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        granted ??= true; // before Android 13 there is nothing to ask
      }
      return granted == true ? NotifyPermission.granted : NotifyPermission.refused;
    } catch (_) {
      return NotifyPermission.refused;
    }
  }

  @override
  Future<void> showNow({required int id, required String title, required String body, required Map<String, Object?> data}) =>
      _plugin.show(id: id, title: title, body: body, payload: jsonEncode(data), notificationDetails: _details);

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
      );

  @override
  Future<void> showLater({
    required int id,
    required String title,
    required String body,
    required Map<String, String> data,
    required Duration after,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: jsonEncode(data),
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(after),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: _details,
    );
  }
}

/// A notification's payload (the push `data`, as JSON) → the data, or null when it isn't one.
Map<String, Object?>? decodePayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } catch (_) {
    return null;
  }
}
