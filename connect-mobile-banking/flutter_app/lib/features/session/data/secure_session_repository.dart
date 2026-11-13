import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session.dart';

// The session in the platform's secure store (Keychain on iOS, Keystore-backed on Android), never in plain
// preferences: the link's secret signs the customer in. The web app keeps the same in localStorage.
class SecureSessionRepository implements SessionRepository {
  SecureSessionRepository([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _mode = 'session.mode';
  static const _origin = 'session.origin';
  static const _secret = 'session.secret';
  // iOS keeps Keychain items after the app is deleted; the app's own preferences go with it. A missing mark means this
  // is the first launch since installing, so anything in the Keychain belongs to an earlier install: forget it.
  static const _installed = 'internetBankingInstalled';

  @override
  Future<Session?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_installed) != true) {
        await forget();
        await prefs.setBool(_installed, true);
        return null;
      }
      final mode = await _storage.read(key: _mode);
      if (mode != 'link') return null; // Sample mode is never restored
      final origin = Uri.tryParse(await _storage.read(key: _origin) ?? '');
      final secret = await _storage.read(key: _secret);
      if (origin == null || origin.scheme != 'https' || secret == null || secret.isEmpty) return null;
      return Session.link(origin: origin, secret: secret);
    } catch (_) {
      return null; // an unreadable store: sign in again
    }
  }

  @override
  Future<void> save(Session session) async {
    await _storage.write(key: _mode, value: session.isSample ? 'sample' : 'link');
    if (session.isSample) {
      await _storage.delete(key: _origin);
      await _storage.delete(key: _secret);
    } else {
      await _storage.write(key: _origin, value: session.origin.toString());
      await _storage.write(key: _secret, value: session.secret);
    }
  }

  @override
  Future<void> forget() async {
    for (final key in [_mode, _origin, _secret]) {
      await _storage.delete(key: key);
    }
  }
}
