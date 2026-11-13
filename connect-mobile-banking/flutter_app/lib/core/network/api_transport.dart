// How the app reaches the banking app's backend: one call, `post(route, body)`, whatever is behind it. Link mode
// sends the session secret in the body to /api/<route>, exactly as the web app does; Sample mode answers from the
// bundled fixtures. A later sign-in (docs/CONTRACT.md section 1, /mobile/v1 with a JWT) is one more transport, with
// no change to any screen.

abstract interface class ApiTransport {
  /// POST one route (for example `app/home`) and return its JSON reply.
  Future<Map<String, dynamic>> post(String route, [Map<String, dynamic> body = const {}]);
}

/// The backend refused: its own words for the customer, and its error code.
class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'error', this.status = 0});

  final String message;
  final String code;
  final int status;

  /// The customer's link no longer works: forget it and go back to sign-in.   [app.js whenExpired]
  bool get linkExpired => status == 403 && code == 'link_expired';

  @override
  String toString() => message;
}
