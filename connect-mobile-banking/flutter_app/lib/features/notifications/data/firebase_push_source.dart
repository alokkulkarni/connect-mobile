import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/assist_intent.dart';

// A real push service: Firebase Cloud Messaging, for iOS (through APNs) and Android. The app ships with no Firebase
// configuration (no google-services.json or GoogleService-Info.plist in the repository), so until the bank adds its
// own, start() finds nothing to set up and this source stays silent. Its taps go to the same handler as the simulated
// push. docs/CONTRACT.md section 7.
class FirebasePushSource implements PushSource {
  final _taps = StreamController<Map<String, Object?>>.broadcast();
  final _foreground = StreamController<({String title, String body, Map<String, Object?> data})>.broadcast();
  bool _ready = false;

  @override
  Stream<Map<String, Object?>> get taps => _taps.stream;

  @override
  Stream<({String title, String body, Map<String, Object?> data})> get foreground => _foreground.stream;

  @override
  Future<void> start() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _taps.add(message.data.cast<String, Object?>()));
      FirebaseMessaging.onMessage.listen((message) => _foreground.add((
            title: message.notification?.title ?? 'Nationwide',
            body: message.notification?.body ?? '',
            data: message.data.cast<String, Object?>(),
          )));
      _ready = true;
      // The device token goes to the bank's own push backend, which isn't part of this demo. Never logged.
    } catch (error) {
      debugPrint('push not configured: ${error.runtimeType}'); // no Firebase configuration: stay silent
    }
  }

  @override
  Future<Map<String, Object?>?> launchData() async {
    if (!_ready) return null;
    try {
      return (await FirebaseMessaging.instance.getInitialMessage())?.data.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }
}
