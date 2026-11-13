import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/conversation.dart';

// The Amazon Connect Participant Service over plain HTTPS, with the participant or connection token as
// X-Amz-Bearer: no AWS SDK and no AWS credentials. The region comes from the start reply. [talk.js participant]
class HttpParticipantApi implements ParticipantApi {
  HttpParticipantApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static Uri base(String region, String path) {
    if (!RegExp(r'^[a-z]{2}(-[a-z]+)+-\d$').hasMatch(region)) {
      throw const ConversationException("We couldn't connect the conversation. Please try again.");
    }
    return Uri.https('participant.connect.$region.amazonaws.com', '/participant/$path');
  }

  @override
  Future<Map<String, dynamic>> post(String region, String path, String bearer, Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await _client
          .post(base(region, path),
              headers: {'content-type': 'application/json', 'X-Amz-Bearer': bearer}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on ConversationException {
      rethrow;
    } catch (_) {
      throw const ConversationException("We couldn't connect the conversation. Please try again.");
    }
    if (response.statusCode >= 400) {
      // Connect's own reason, for the debug console only (it never contains a token).
      String reason = '';
      try {
        final json = jsonDecode(response.body);
        if (json is Map) reason = '${json['Message'] ?? json['message'] ?? ''}';
      } catch (_) {}
      debugPrint('Connect participant $path failed: ${response.statusCode} $reason');
      throw ConversationException("We couldn't connect the conversation (${response.statusCode}). Please try again.");
    }
    if (response.body.isEmpty) return const {};
    try {
      final json = jsonDecode(response.body);
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }
}

/// The chat's websocket (wss only).
class WebSocketChatSocket implements ChatSocket {
  WebSocketChatSocket._(this._channel) : frames = _channel.stream.map((frame) => frame is String ? frame : utf8.decode(frame as List<int>));

  final WebSocketChannel _channel;

  @override
  final Stream<String> frames;

  static Future<ChatSocket> connect(Uri url) async {
    if (url.scheme != 'wss') throw const ConversationException("We couldn't connect the conversation. Please try again.");
    final channel = WebSocketChannel.connect(url);
    await channel.ready;
    return WebSocketChatSocket._(channel);
  }

  @override
  void send(String frame) {
    try {
      _channel.sink.add(frame);
    } catch (_) {
      // closed meanwhile
    }
  }

  @override
  Future<void> close() async {
    try {
      await _channel.sink.close();
    } catch (_) {}
  }
}
