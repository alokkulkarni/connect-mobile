import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/conversation.dart';

// The native call: the Amazon Chime SDK on iOS (ios/Runner/ConnectCallPlugin.swift) and Android
// (android/app/src/main/kotlin/.../ConnectCallPlugin.kt), behind the `connect_call` channels. Only these cross:
//   methods  join({meeting, attendee}), setMuted({muted}), leave()
//   events   {type: connected}, {type: stopped, code}, {type: error, message}
class ChimeCallMedia implements CallMedia {
  ChimeCallMedia({MethodChannel? methods, EventChannel? events})
      : _methods = methods ?? const MethodChannel('connect_call'),
        _eventChannel = events ?? const EventChannel('connect_call/events');

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  Stream<CallMediaEvent>? _events;

  @override
  Stream<CallMediaEvent> get events => _events ??= _eventChannel.receiveBroadcastStream().map((raw) {
        final event = (raw as Map).cast<String, Object?>();
        return switch (event['type']) {
          'connected' => const CallMediaEvent(CallMediaEventType.connected),
          'stopped' => CallMediaEvent(CallMediaEventType.stopped, code: event['code'] as int?),
          _ => CallMediaEvent(CallMediaEventType.error, message: event['message'] as String?),
        };
      }).asBroadcastStream();

  @override
  Future<void> join(Map<String, dynamic> meeting, Map<String, dynamic> attendee) async {
    try {
      await _methods.invokeMethod<void>('join', {'meeting': meeting, 'attendee': attendee});
    } on MissingPluginException {
      throw const ConversationException('Calls need the app installed on a phone.');
    } on PlatformException catch (error) {
      throw ConversationException(error.message ?? 'The call could not start.');
    }
  }

  @override
  Future<void> setMuted(bool muted) => _methods.invokeMethod<void>('setMuted', {'muted': muted});

  @override
  Future<void> leave() async {
    try {
      await _methods.invokeMethod<void>('leave');
    } on MissingPluginException {
      // nothing to leave
    }
  }
}

class PermissionMicrophone implements Microphone {
  @override
  Future<bool> request() async => (await Permission.microphone.request()).isGranted;
}
