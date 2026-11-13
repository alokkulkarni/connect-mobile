import 'package:flutter/foundation.dart';

import '../domain/session.dart';

// Signed in or not, for the router and the transport. A ChangeNotifier so the router can listen to it directly.
enum SessionStatus { loading, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this._repository);

  final SessionRepository _repository;
  SessionStatus status = SessionStatus.loading;
  Session? session;

  /// The words to show on the sign-in screen (for example why the link stopped working).
  String? notice;

  Future<void> restore() async {
    session = await _repository.load();
    status = session == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    notifyListeners();
  }

  /// The link the customer pasted or opened. Returns why it can't be used, or null when signed in.
  Future<String?> signInWithLink(String text) async {
    final parsed = parseLink(text);
    if (!parsed.ok) return parsed.error;
    await _signIn(Session.link(origin: parsed.origin!, secret: parsed.secret!));
    return null;
  }

  /// Sample mode lives in memory only, and forgets any saved link: the next launch opens on sign-in, so the customer
  /// can always get back to pasting their link.
  Future<void> exploreSample() async {
    try {
      await _repository.forget();
    } catch (_) {
      // a store that can't be written still lets the customer look around
    }
    _show(const Session.sample());
  }

  Future<void> _signIn(Session next) async {
    await _repository.save(next);
    _show(next);
  }

  void _show(Session next) {
    session = next;
    notice = null;
    status = SessionStatus.signedIn;
    notifyListeners();
  }

  /// "Forget this device", or a link that no longer works.   [app.js forget]
  Future<void> forget({String? because}) async {
    await _repository.forget();
    session = null;
    notice = because;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
