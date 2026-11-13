import 'package:connect_banking/features/session/domain/session.dart';
import 'package:connect_banking/features/session/presentation/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements SessionRepository {
  Session? saved;
  final saves = <Session>[];
  bool failForget = false;

  @override
  Future<Session?> load() async => saved;

  @override
  Future<void> save(Session session) async {
    saves.add(session);
    saved = session;
  }

  @override
  Future<void> forget() async {
    if (failForget) throw StateError('keychain unavailable');
    saved = null;
  }
}

// Sample mode is never saved, so the next launch opens on sign-in and the customer can paste their link.
void main() {
  test('Sample mode is never saved, and forgets a saved link', () async {
    final store = _Store();
    final sessions = SessionController(store);
    await sessions.signInWithLink('https://app.example/#k=abcdefghijklmnopQRST_-12');
    await sessions.exploreSample();
    expect(sessions.status, SessionStatus.signedIn);
    expect(sessions.session!.isSample, isTrue);
    expect(store.saves.map((s) => s.mode), [SessionMode.link]);

    final nextLaunch = SessionController(store);
    await nextLaunch.restore();
    expect(nextLaunch.status, SessionStatus.signedOut);
  });

  test('Sample mode still starts when the secure store fails', () async {
    final sessions = SessionController(_Store()..failForget = true);
    await sessions.exploreSample();
    expect(sessions.session!.isSample, isTrue);
  });
}
