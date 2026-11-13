import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart' show sessionControllerProvider;
import '../../assistant/presentation/assistant_providers.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../cards/presentation/cards_providers.dart';
import '../../home/presentation/home_providers.dart';
import '../../money_hub/domain/money_hub.dart';
import '../../session/presentation/session_controller.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../domain/assist_intent.dart';

// One handler for every notification, real push or local: validate it, go to its screen, and (for money) start a
// chat or call there once the screen has said where the customer is. docs/CONTRACT.md section 7, "What the app does".
class IntentRunner {
  IntentRunner({required this.container, required this.router, required this.navigatorContext});

  final ProviderContainer container;
  final GoRouter router;
  final BuildContext? Function() navigatorContext;

  AssistIntent? _pending; // until sign-in, in memory only

  /// A notification's data, from any source.
  Future<void> handleData(Map<String, Object?> data) => handle(parseAssistIntent(data));

  Future<void> handle(AssistIntent intent) async {
    if (container.read(sessionControllerProvider).status != SessionStatus.signedIn) {
      _pending = intent;
      return;
    }
    await _run(intent);
  }

  /// Signed in: run the notification that arrived before.
  Future<void> signedIn() async {
    final pending = _pending;
    _pending = null;
    if (pending != null) await _run(pending);
  }

  static String pathFor(IntentScreen screen, MoneyHubView? view, {String? transactionId}) => switch (screen) {
        IntentScreen.home => '/home',
        IntentScreen.accounts => '/accounts/current',
        IntentScreen.cards => '/cards',
        IntentScreen.cardsDisputes => '/cards/disputes',
        IntentScreen.moneyHub => '/money-hub/${(view ?? MoneyHubView.out).key}',
        IntentScreen.transaction => '/home/transactions/$transactionId',
        IntentScreen.mortgages => '/more/mortgages',
      };

  Future<void> _run(AssistIntent intent) async {
    var screen = intent.screen;
    var view = intent.view;
    String? chosenPayment;
    var path = pathFor(screen, view, transactionId: intent.transactionId);
    final fallback = pathFor(intent.fallbackScreen, intent.fallbackView);

    // A payment must be one of the customer's own card payments; a transaction must be found.
    if (intent.screen == IntentScreen.cards) {
      container.read(cardsSelectionProvider).choose(null);
      final id = intent.paymentId;
      if (id != null) {
        try {
          final payment = (await container.read(cardsViewProvider.future)).payment(id);
          if (payment != null) {
            container.read(cardsSelectionProvider).choose(payment);
            chosenPayment = id;
          }
        } catch (_) {}
      }
    } else if (intent.screen == IntentScreen.transaction) {
      final id = intent.transactionId!;
      try {
        if (await container.read(transactionByIdProvider(id).future) == null) path = fallback;
      } catch (_) {
        path = fallback;
      }
      if (path == fallback) (screen, view) = (intent.fallbackScreen, intent.fallbackView);
    }

    router.go(path);
    if (!intent.autoStart) return;
    // Only once the screen says what the notification asked for (not an old tab), or after 6 s.
    final expected = expectedContext(screen, view: view, paymentId: chosenPayment);
    await container.read(screenContextsProvider).whenShowing(path, matches: expected.matches, timeout: intentContextWait);
    try {
      await container.read(homeSummaryProvider.future); // whether chat and calls are on
    } catch (_) {}
    final context = navigatorContext();
    if (context == null || !context.mounted) return;
    final assistant = container.read(assistantControllerProvider);
    // A conversation already going: don't start another; the page move tells the assistant where they are.
    await showAssistantSheet(context, startWith: assistant.live ? null : intent.mode);
  }
}
