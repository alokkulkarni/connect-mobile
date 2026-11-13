import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_transport.dart';

// Link mode: POST <origin>/api/<route> with the session secret as `token` in the body, as the web app does
// (connect-banking-app/web/lib.js api). Nothing else names the customer. Only the route and status are logged,
// never a body or the secret.
class LinkTransport implements ApiTransport {
  LinkTransport({required this.origin, required String secret, this.onExpired, http.Client? client})
      // ignore: prefer_initializing_formals
      : _secret = secret, // private, and named `secret` for callers
        _client = client ?? http.Client();

  final Uri origin;
  final String _secret;

  /// The link no longer works: the app forgets it and goes back to sign-in.
  final void Function()? onExpired;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> post(String route, [Map<String, dynamic> body = const {}]) async {
    final url = origin.replace(path: '/api/$route');
    http.Response response;
    try {
      response = await _client
          .post(url,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({...body, 'token': _secret}))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ApiException("We couldn't reach internet banking. Check your connection and try again.",
          code: 'network');
    }
    debugPrint('api route=$route status=${response.statusCode}');
    Map<String, dynamic> reply;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      reply = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      reply = <String, dynamic>{};
    }
    if (response.statusCode >= 400) {
      final error = ApiException(
        (reply['message'] as String?) ?? 'Something went wrong. Try again.',
        code: (reply['error'] as String?) ?? 'error',
        status: response.statusCode,
      );
      if (error.linkExpired) onExpired?.call();
      throw error;
    }
    return reply;
  }
}
