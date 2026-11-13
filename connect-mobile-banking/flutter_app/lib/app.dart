import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/presentation/assistant_providers.dart';
import 'features/notifications/presentation/intent_runner.dart';
import 'features/notifications/presentation/notifications_providers.dart';
import 'features/session/presentation/session_controller.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

// The app: themes, the router, and the app-wide wiring the screens don't own: notifications (real push and the
// simulated local ones) all go to one handler; a chat survives the app going to the background (C13).
class BankApp extends ConsumerStatefulWidget {
  const BankApp({super.key, this.wirePush = true});

  /// Tests leave the notification plugins out.
  final bool wirePush;

  @override
  ConsumerState<BankApp> createState() => _BankAppState();
}

class _BankAppState extends ConsumerState<BankApp> with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<Object?>>[];
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final runner = IntentRunner(
      container: ProviderScope.containerOf(context, listen: false),
      router: ref.read(routerProvider),
      navigatorContext: () => rootNavigatorKey.currentContext,
    );
    ref.read(intentRunnerHolderProvider).runner = runner;
    if (widget.wirePush) WidgetsBinding.instance.addPostFrameCallback((_) => _wirePush(runner));
  }

  // Every source's taps, and the notification that launched the app (run after sign-in has loaded).
  Future<void> _wirePush(IntentRunner runner) async {
    for (final source in ref.read(pushSourcesProvider)) {
      await source.start();
      _subscriptions.add(source.taps.listen(runner.handleData));
      // A push that arrives while the app is open is shown again as a local notification, so its tap goes to the
      // same handler as every other notification.
      _subscriptions.add(source.foreground.listen((n) => ref
          .read(localNotifierProvider)
          .showNow(id: 200 + (_shown++ % 100), title: n.title, body: n.body, data: n.data)
          .catchError((Object _) {})));
      final launched = await source.launchData();
      if (launched != null) await runner.handleData(launched);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(assistantControllerProvider).setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider.select((s) => s.status), (_, status) {
      if (status == SessionStatus.signedIn) ref.read(intentRunnerHolderProvider).runner?.signedIn();
    });
    return MaterialApp.router(
      title: 'Nationwide',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: bankTheme(Brightness.light),
      darkTheme: bankTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
