// Who is using the app, and how. The demo has no username or password: the internet banking link stands for the
// customer signed in (connect-banking-app/README.md). docs/CONTRACT.md section 1.

enum SessionMode { sample, link }

class Session {
  const Session.sample()
      : mode = SessionMode.sample,
        origin = null,
        secret = null;

  const Session.link({required Uri this.origin, required String this.secret}) : mode = SessionMode.link;

  final SessionMode mode;

  /// The backend's address (the link's origin): the API base and the forms WebView's allowed origin.
  final Uri? origin;

  /// The link's secret (after `#k=`). Kept in the secure store only.
  final String? secret;

  bool get isSample => mode == SessionMode.sample;
}

/// Where sign-in keeps the session between launches (the platform's secure store).
abstract interface class SessionRepository {
  Future<Session?> load();
  Future<void> save(Session session);
  Future<void> forget();
}

/// The link the customer gave, read once: its origin and its secret, or why it can't be used.
class LinkParseResult {
  const LinkParseResult.ok(Uri this.origin, String this.secret) : error = null;
  const LinkParseResult.failed(String this.error)
      : origin = null,
        secret = null;

  final Uri? origin;
  final String? secret;
  final String? error;

  bool get ok => error == null;
}

final _secret = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// `https://<app-host>/<any path>#k=<secret>` → origin and secret. Only https; the secret must look like one.
LinkParseResult parseLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const LinkParseResult.failed("That doesn't look like your internet banking link.");
  }
  if (uri.scheme != 'https') {
    return const LinkParseResult.failed('Your internet banking link must start with https://.');
  }
  final fragment = uri.fragment;
  final secret = fragment.startsWith('k=') ? fragment.substring(2) : '';
  if (!_secret.hasMatch(secret)) {
    return const LinkParseResult.failed("That link is missing its secure part (after #k=). Copy the whole link.");
  }
  final origin = Uri(scheme: 'https', host: uri.host, port: uri.hasPort ? uri.port : null);
  return LinkParseResult.ok(origin, secret);
}
