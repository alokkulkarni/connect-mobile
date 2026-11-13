import 'package:connect_banking/features/assistant/domain/screen_context.dart';
import 'package:connect_banking/features/assistant/presentation/screen_contexts.dart';
import 'package:connect_banking/features/money_hub/domain/money_hub.dart';
import 'package:connect_banking/features/notifications/domain/assist_intent.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// docs/CONTRACT.md section 7, step 4: a notification starts the conversation only once its screen says what the
// notification asked for (not an old tab), or 6 s after arriving.
void main() {
  const outTab = ScreenContext(page: 'money_hub', view: 'out', label: 'Money Hub · Money out', launcher: 'Ask about your money');
  const inTab = ScreenContext(page: 'money_hub', view: 'in', label: 'Money Hub · Money in', launcher: 'Ask about your money');
  const cards = ScreenContext(page: 'cards', label: 'Cards', launcher: 'Help with a payment');
  const disputing = ScreenContext(page: 'card_dispute', paymentId: 'TXN-2291-20261004-61200', label: 'Disputing', launcher: 'Help with a payment');

  test('the expected context: page, and the tab or payment the intent names', () {
    final hubIn = expectedContext(IntentScreen.moneyHub, view: MoneyHubView.moneyIn);
    expect(hubIn.matches(inTab), isTrue);
    expect(hubIn.matches(outTab), isFalse); // the old tab
    final payment = expectedContext(IntentScreen.cards, paymentId: 'TXN-2291-20261004-61200');
    expect(payment.matches(disputing), isTrue);
    expect(payment.matches(cards), isFalse);
    expect(expectedContext(IntentScreen.cards).matches(cards), isTrue);
    expect(expectedContext(IntentScreen.transaction).matches(const ScreenContext(page: 'money_hub', view: 'transactions', label: 'x', launcher: 'y')), isTrue);
    expect(expectedContext(IntentScreen.mortgages).matches(cards), isFalse);
  });

  test('an already-open screen with its old tab doesn\'t count; the new tab does', () {
    fakeAsync((async) {
      final contexts = ScreenContexts()
        ..showing('/money-hub/out')
        ..publish('/money-hub/out', outTab);
      ScreenContext? got;
      contexts
          .whenShowing('/money-hub/in', matches: expectedContext(IntentScreen.moneyHub, view: MoneyHubView.moneyIn).matches, timeout: intentContextWait)
          .then((c) => got = c);
      contexts.showing('/money-hub/in');
      async.elapse(const Duration(seconds: 1));
      expect(got, isNull); // showing, but the screen hasn't said where it is yet
      contexts.publish('/money-hub/in', inTab);
      async.flushMicrotasks();
      expect(got, inTab);
    });
  });

  test('if the screen never says, it starts anyway after 6 s', () {
    fakeAsync((async) {
      final contexts = ScreenContexts()
        ..showing('/cards')
        ..publish('/cards', cards);
      ScreenContext? got;
      contexts
          .whenShowing('/cards', matches: expectedContext(IntentScreen.cards, paymentId: 'TXN-2291-20261004-61200').matches, timeout: intentContextWait)
          .then((c) => got = c);
      async.elapse(const Duration(milliseconds: 5900));
      expect(got, isNull);
      async.elapse(const Duration(milliseconds: 100));
      expect(got, cards);
    });
  });
}
