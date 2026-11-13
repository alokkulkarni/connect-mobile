import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/session/data/secure_session_repository.dart';
import '../../features/session/presentation/session_controller.dart';
import '../network/api_transport.dart';
import '../network/link_transport.dart';
import '../network/sample_transport.dart';

// The app's shared wiring: the session, the transport that follows it, the bundled fixtures, and a counter that
// makes every screen's data reload (after the assistant says something, or a conversation ends). Each feature
// keeps its own providers next to its screens.

final fixtureLoaderProvider = Provider<FixtureLoader>((ref) => (name) => rootBundle.loadString('assets/fixtures/$name.json'));

final sessionControllerProvider = ChangeNotifierProvider<SessionController>((ref) => SessionController(SecureSessionRepository()));

const linkExpiredWords = 'That link no longer works. Open your internet banking from a new link.';

/// Sample mode reads the fixtures; Link mode calls the backend with the link's secret. Changes with the session.
final transportProvider = Provider<ApiTransport>((ref) {
  final session = ref.watch(sessionControllerProvider.select((c) => c.session));
  if (session == null || session.isSample) return SampleTransport(ref.watch(fixtureLoaderProvider));
  return LinkTransport(
    origin: session.origin!,
    secret: session.secret!,
    onExpired: () => ref.read(sessionControllerProvider).forget(because: linkExpiredWords),
  );
});

/// Bumped when the customer's data may have changed: screens' providers watch it and reload.   [talk.js onActivity]
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);
